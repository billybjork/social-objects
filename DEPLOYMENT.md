# Hudson Desktop Deployment (Tauri + Phoenix)

A revised plan to ship Hudson as a cross‑platform desktop app using **Tauri** as the shell, while keeping the existing **Phoenix/LiveView** UI and adding a **SQLite + Neon** hybrid data layer plus media caching. This addresses the gaps in `DEPLOYMENT.md` (env bootstrapping, credentials, updates, NIF/toolchain, offline tolerance, signing).

## Goals
- Preserve current LiveView UI; avoid template rewrites.
- Better desktop UX: native window/tray, smoother updates, no exposed public port, notarized/signable installers.
- Lower latency and add offline tolerance with a local cache (SQLite + media cache) while keeping Neon as the source of truth.
- Reduce deployment risk: no client-run DB migrations; safer secrets handling; integrity-checked updates.

## High-Level Architecture
- **Tauri shell** (Rust): boots BEAM release, manages lifecycle, native menus/tray, updater, and loads the Phoenix UI in the WebView (`http://127.0.0.1:<ephemeral_port>`). No UI rewrite.
- **Phoenix/LiveView** (unchanged UI): served locally. Endpoint binds to loopback on an ephemeral port handed to Tauri.
- **Data**: SQLite for low-latency/offline cache + Neon Postgres for authoritative data. Operation queue syncs to Neon with retries/conflict rules.
- **Media**: disk cache keyed by URL with TTL/size cap; prefetch per session.
- **Updates**: Tauri updater (or custom) with signature + checksum verification and rollback.

## Detailed Plan

### 1) Desktop Shell (Tauri)
- Add a Tauri workspace with a minimal Rust command that:
  - Spawns the Burrito/BEAM release as a child process.
  - Reads the chosen port from a small handshake file (`/tmp/hudson_port.json` on macOS, `%APPDATA%\Hudson\port.json` on Windows) containing `{"port": <int>}`; fallback: parse the first `PORT:<int>` line on stdout.
  - Waits for `/healthz` on that port with timeout/backoff, then loads WebView to that URL.
  - For shutdown, sends a TERM to BEAM and waits; on update, stop BEAM before replacing binaries.
- Disable remote content in WebView; allow only `127.0.0.1` + `localhost`. Set a strict Content-Security-Policy.
- Native chrome: menu/tray shortcut to open settings, restart, check for updates, open logs.

### 2) Runtime Bootstrap (Elixir)
- Adjust `config/runtime.exs` to:
  - Load persisted settings/creds from keychain/DPAPI-backed store; do **not** raise when env is missing on first run.
  - Generate `secret_key_base` on first run and persist in secure storage (not alongside the creds file).
  - Pick a random available port (unless `PORT` set), bind to `{127,0,0,1}`, and write the port to the handshake file for Tauri.
  - Keep Repo pool small (3–5) and tolerant of reconnects; add backoff/circuit-breaker behavior for Neon connectivity.
- Secure storage libraries:
  - macOS: OS Keychain via a small adapter (e.g., `:keychainx` or a Rust shim exposed via NIF/Port) with `get/put/delete`.
  - Windows: DPAPI/WinCred via adapter (e.g., `:wincred` or Rust bridge) with the same `get/put/delete` surface.

### 3) Data Layer: SQLite + Neon
- Add a local SQLite file (`~/Library/Application Support/Hudson/local.db` on macOS, `%APPDATA%\Hudson\local.db` on Windows).
- Define schema and migrations for SQLite separately from Neon. Keep them tiny and stable; **auto-run SQLite migrations on client startup** (safe because local).
- Add a sync/queue process:
  - Write ops to SQLite first; enqueue outbound mutations to Neon with retries/backoff.
  - On startup/online, pull deltas from Neon (timestamp/high-water mark) and reconcile (domain-specific conflict rules or last-write-wins).
  - For read paths, prefer SQLite cached data; fall back to Neon on cache miss when online.
- Keep Oban/Notifiers: run workers only if they are local-only tasks; otherwise point Oban to Neon via small pools and handle latency or disable as needed.
- Do **not** run `ecto.migrate` against Neon from clients. Migrations run in CI/CD before releasing binaries. On startup, check Neon schema version; if too far ahead, show “Update required” and refuse to start to avoid drift.
  - Schema gate: read `SELECT max(version) FROM schema_migrations`; if client code expects `N` and Neon is > N, require update before proceeding (threshold default 0).
- Conflict rules (initial pass):
  - Product catalog: last-write-wins (Shopify is source of truth; prefer fresh pull).
  - Session state (per user/session): local-first; sync up, but conflicts prompt user to choose.
  - Talking points/AI generations: append-only with timestamps; dedupe on merge.
  - Provide a conflict UI/log for visibility on auto-resolutions.

### 4) Media Cache
- Add a Req-based downloader with disk cache (URL-keyed) with TTL + LRU/size cap (default: **500MB cap, 7-day TTL**, configurable in settings).
- Prefetch session media when online; on offline, serve cached assets or placeholders.
- Store cache under the same app-data root (`media-cache/`). Periodic cleanup task.

### 5) Credentials & Secrets
- Storage: OS keychain (macOS) / DPAPI (Windows). If a file store is unavoidable, use envelope encryption with a key retrieved from OS secure storage; never store the key next to the ciphertext.
- Avoid `System.put_env/2` for secrets; keep them in memory and inject into clients at call time.
- Redact secrets from logs; ensure log rotation per-user under app-data `logs/`.

### 6) Updates
- Use Tauri’s auto-updater or custom flow that:
  - Downloads to temp file, verifies SHA256 + detached signature (ship a public key in the app).
  - Stops BEAM, atomically swaps binaries, keeps a rollback copy.
  - Supports staged rollout by channel (`stable`/`beta`).
- macOS: signed + notarized; Windows: Authenticode signing; both include updater signature checks.

### 7) Build & Packaging
- CI matrix: macOS for mac builds/notarization; Windows runner for Windows build/signing (avoid cross-building NIFs). Validate NIF load on each target via a smoke test.
- Tauri builds installers; Phoenix release embedded asset bundle. Keep `esbuild` pipeline and `phx.digest`.
- Entitlements: keep minimal (likely no `allow-unsigned-executable-memory` needed). Windows installer adds Start Menu shortcut and optional firewall rule for loopback port if required.
- Sidecar wiring: keep Burrito output under `burrito_out/` and **symlink** into `tauri/src-tauri` using Tauri’s expected naming (`hudson_backend-<target-triple>[.exe]`) to avoid copy steps.
- Toolchains: lock Zig versions per target (e.g., cargo-xwin + Zig 0.13.0 for Windows) to avoid build flakiness.

### 8) Networking / Firewall / Ports
- Bind Phoenix to loopback only; choose a random free port to minimize conflicts.
- Health endpoint (`/healthz`) for Tauri readiness.
- Handle firewall prompts gracefully; document that no inbound LAN access is required.

### 9) Observability & UX
- Add a diagnostics page in the UI: Neon connectivity, Shopify/OpenAI reachability, clock skew, cache status, update availability.
- Show offline/online state and queue depth in the UI; allow manual “sync now”. Add a small health indicator (🟢/🟡/🔴) in the navbar.
- Provide a conflict viewer for sync collisions; log auto-resolutions.
- Crash reporting (opt-in) with redaction; consider Sentry with consent.

### 10) Offline/Online Capability Matrix (initial)
| Feature                  | Offline | Online Required |
|--------------------------|---------|-----------------|
| View cached products     | ✅       | —               |
| View fresh products      | ❌       | ✅              |
| Create session (local)   | ✅       | —               |
| Add products to session  | ✅       | —               |
| Generate talking points  | ❌       | ✅ (OpenAI)     |
| Shopify sync             | ❌       | ✅              |
| Start live stream        | ✅       | ✅ (TikTok APIs)|

### 10) Testing/Verification
- Add automated smoke for each target:
  - Launch BEAM, hit `/healthz`, open WebView URL, verify bcrypt/lazy_html NIFs load.
  - SQLite migration + cache read/write.
  - Update flow in temp dir (download, verify, swap, rollback).
- Keep `mix precommit` green; add unit tests for the sync queue and media cache.

## Pilot (de-risk before full build)
- Goal: validate core lifecycle and platform blockers in 1–2 days before deeper work.
- Steps:
  - Add `/healthz` endpoint and random loopback port selection; write handshake file; ensure boot succeeds with no env (first-run friendly).
  - Minimal Tauri shell: read handshake, poll `/healthz`, load WebView; show clear error on timeout.
  - Smoke NIFs on macOS (bcrypt_elixir, lazy_html) with the Burrito build; ensure no load failures.
  - Local SQLite Repo + auto-migration run on startup (empty schema) to confirm migration path.
  - Manual start/stop: confirm Tauri cleanly terminates BEAM.

## Action Items (initial cut)
- Add Tauri workspace + Rust bootstrap to spawn BEAM and load LiveView URL.
- Update `config/runtime.exs` to first-run-friendly boot (no required env raises), random loopback port, secure secret storage hook, health endpoint.
- Introduce SQLite cache schema + sync queue scaffolding; keep Neon migrations CI-only.
- Implement Req-based media cache with TTL/LRU.
- Wire Tauri updater with signature verification and rollback; add release signing keys to CI secrets.
- Add diagnostics UI + offline/online indicators.
- Validate bcrypt/lazy_html NIF loading per target in CI.

## Timeline & Effort Estimation

**Total Estimated Duration:** 18-20 working days

| Phase | Tasks | Duration | Dependencies |
|-------|-------|----------|--------------|
| **Phase 1: Foundation** | Tauri setup, Burrito config, health endpoint, port handshake | 2 days | — |
| **Phase 2: Data Layer** | SQLite Repo, sync queue, conflict resolution, schema versioning | 4 days | Phase 1 |
| **Phase 3: Credentials** | OS keychain/DPAPI integration, secure storage module | 2 days | Phase 1 |
| **Phase 4: Media Cache** | Req-based cache, LRU/TTL logic, prefetch | 1 day | Phase 2 |
| **Phase 5: Updates** | Tauri updater, signature verification, rollback | 2 days | Phase 1 |
| **Phase 6: UX & Diagnostics** | Settings UI, health indicators, conflict viewer, first-run wizard | 3 days | Phase 2, 3 |
| **Phase 7: Build & CI/CD** | GitHub Actions, code signing, notarization, installers | 2 days | All above |
| **Phase 8: Testing** | Multi-platform testing, offline scenarios, NIF validation | 2-3 days | All above |

**Critical Path:** Phase 1 → Phase 2 → Phase 6 → Phase 7 → Phase 8

## Dependencies & Tooling Requirements

### Development Machine Setup

**Required:**
- Elixir 1.15+ and Erlang/OTP 26+
- Rust 1.70+ (for Tauri)
- Zig 0.13.0 (exact version for Burrito Windows builds)
- Node.js 18+ (for Tauri CLI, not for Phoenix assets)
- Git

**Platform-Specific:**
- **macOS:** Xcode Command Line Tools, Apple Developer account/certificates
- **Windows:** Visual Studio Build Tools 2019+, Windows SDK

**Install Commands:**
```bash
# macOS
brew install elixir rust zig@0.13.0 node
rustup update stable

# Tauri CLI
cargo install tauri-cli

# Windows cross-compilation (from macOS/Linux)
cargo install cargo-xwin
```

### Elixir Dependencies (add to mix.exs)

```elixir
defp deps do
  [
    # ... existing deps
    {:burrito, "~> 1.5", runtime: false},
    {:ecto_sqlite3, "~> 0.9"},
    {:req, "~> 0.5"},  # Already present
    # Secure storage adapters
    {:ex_os_keychain, "~> 0.1"},  # macOS keychain (if available)
    # OR build custom Rust NIF/Port bridge
  ]
end
```

### Rust Dependencies (Cargo.toml in src-tauri/)

```toml
[dependencies]
tauri = { version = "1.5", features = ["shell-open"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1", features = ["full"] }

[target.'cfg(target_os = "macos")'.dependencies]
security-framework = "2.9"  # For keychain access

[target.'cfg(target_os = "windows")'.dependencies]
windows = { version = "0.51", features = ["Win32_Security_Credentials"] }
```

## Project File Structure

```
hudson/
├── lib/
│   ├── hudson/
│   │   ├── sync/              # NEW: SQLite ↔ Neon sync queue
│   │   │   ├── queue.ex
│   │   │   ├── reconciler.ex
│   │   │   └── conflict_resolver.ex
│   │   ├── cache/             # NEW: Media cache
│   │   │   ├── media_cache.ex
│   │   │   └── lru_store.ex
│   │   ├── secure_storage.ex  # NEW: Keychain/DPAPI adapter
│   │   ├── local_repo.ex      # NEW: SQLite Repo
│   │   └── release.ex         # NEW: Migration runner
│   └── hudson_web/
│       └── live/
│           ├── settings_live/ # UPDATED: Add credentials UI
│           └── diagnostics_live/ # NEW: Health/sync dashboard
├── priv/
│   └── repo/
│       ├── migrations/        # Neon (CI-run only)
│       └── local_migrations/  # NEW: SQLite (client-run)
├── src-tauri/                 # NEW: Tauri Rust project
│   ├── src/
│   │   ├── main.rs           # Window setup, sidecar lifecycle
│   │   ├── backend.rs        # BEAM process management
│   │   └── secure_storage.rs # Keychain/DPAPI bridge (optional)
│   ├── tauri.conf.json
│   └── Cargo.toml
├── config/
│   └── runtime.exs            # UPDATED: First-run friendly
├── .github/
│   └── workflows/
│       └── release.yml        # NEW: CI/CD pipeline
└── scripts/
    ├── build_sidecar.sh       # Burrito build wrapper
    └── link_binaries.sh       # Symlink burrito_out → src-tauri
```

## CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build-macos:
    runs-on: macos-latest
    strategy:
      matrix:
        target: [aarch64-apple-darwin, x86_64-apple-darwin]
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - uses: dtolnay/rust-toolchain@stable
      - uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.13.0

      - name: Install Tauri CLI
        run: cargo install tauri-cli

      - name: Build BEAM sidecar
        run: |
          mix deps.get --only prod
          MIX_ENV=prod mix assets.deploy
          MIX_ENV=prod mix release
          ./scripts/link_binaries.sh ${{ matrix.target }}

      - name: Build Tauri app
        run: |
          cd src-tauri
          cargo tauri build --target ${{ matrix.target }}

      - name: Code sign & notarize
        env:
          APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
          APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          # Import certificate
          echo "$APPLE_CERTIFICATE" | base64 --decode > certificate.p12
          security create-keychain -p actions build.keychain
          security import certificate.p12 -k build.keychain -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k actions build.keychain

          # Sign
          codesign --force --deep --sign "Developer ID Application" \
            src-tauri/target/${{ matrix.target }}/release/bundle/macos/Hudson.app

          # Notarize
          xcrun notarytool submit \
            src-tauri/target/${{ matrix.target }}/release/bundle/dmg/Hudson_*.dmg \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

          # Staple
          xcrun stapler staple src-tauri/target/${{ matrix.target }}/release/bundle/dmg/Hudson_*.dmg

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: hudson-macos-${{ matrix.target }}
          path: src-tauri/target/${{ matrix.target }}/release/bundle/dmg/Hudson_*.dmg

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - uses: dtolnay/rust-toolchain@stable
      - uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.13.0

      - name: Install Tauri CLI
        run: cargo install tauri-cli

      - name: Build BEAM sidecar
        shell: bash
        run: |
          mix deps.get --only prod
          MIX_ENV=prod mix assets.deploy
          MIX_ENV=prod mix release
          ./scripts/link_binaries.sh x86_64-pc-windows-msvc

      - name: Build Tauri app
        run: |
          cd src-tauri
          cargo tauri build

      - name: Code sign (if certificate available)
        if: ${{ secrets.WINDOWS_CERTIFICATE }}
        shell: powershell
        run: |
          # Sign with SignTool
          # Add signing logic here

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: hudson-windows-x86_64
          path: src-tauri/target/release/bundle/msi/Hudson_*.msi

  create-release:
    needs: [build-macos, build-windows]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
      - uses: softprops/action-gh-release@v1
        with:
          files: |
            hudson-macos-*/*.dmg
            hudson-windows-*/*.msi
          draft: false
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Error Handling & Graceful Degradation

### Startup Failure Scenarios

| Scenario | Detection | Response |
|----------|-----------|----------|
| No credentials configured | `Hudson.SecureStorage.get("neon_url") == nil` | Redirect to first-run wizard |
| Neon unreachable | Connection timeout > 10s | Start in offline mode, show banner |
| Neon schema too new | `neon_version > expected_version` | Block startup, show "Update Required" dialog |
| SQLite corruption | `Ecto.Adapters.SQL.query!` raises | Delete local.db, re-sync from Neon, log incident |
| Port conflict | `Bandit.start_link` fails | Retry with 3 random ports, then error |
| NIF load failure | `bcrypt_elixir` or `lazy_html` error | Log to file, show "Installation corrupted" dialog |

### Runtime Failure Scenarios

| Scenario | Detection | Response |
|----------|-----------|----------|
| Neon connection lost | Active query fails | Queue writes, show offline indicator |
| Shopify API rate limit | HTTP 429 response | Exponential backoff, show sync delay estimate |
| OpenAI API failure | HTTP 5xx or timeout | Retry 3x, then disable AI features temporarily |
| Disk cache full | Write fails | Evict LRU entries, reduce cache cap by 20% |
| Sync conflict | Timestamp collision | Log conflict, apply domain rule, notify user if manual resolution needed |

### Recovery Mechanisms

```elixir
# lib/hudson/sync/circuit_breaker.ex
defmodule Hudson.Sync.CircuitBreaker do
  use GenServer

  # State: :closed (healthy), :open (failing), :half_open (testing)
  # Open after 5 consecutive failures
  # Half-open after 60s
  # Close after 1 successful request in half-open

  def call(fun) do
    case get_state() do
      :closed -> try_request(fun)
      :open -> {:error, :circuit_open}
      :half_open -> test_request(fun)
    end
  end
end
```

## First-Run Setup Flow (UX)

### Initial Launch Sequence

1. **App starts** → Tauri boots → BEAM spawns
2. **No credentials found** → `Hudson.SecureStorage.first_run? == true`
3. **WebView loads** → `/setup/welcome` (bypasses auth check)
4. **Setup wizard** (LiveView multi-step form):
   - **Step 1:** Welcome screen with product explanation
   - **Step 2:** Neon database URL input + test connection button
   - **Step 3:** Shopify credentials (store name + access token) + test
   - **Step 4:** OpenAI API key + test
   - **Step 5:** Initial sync (pull products from Shopify → SQLite)
   - **Step 6:** Success screen → redirect to `/sessions`

### Credential Validation UI

```elixir
# lib/hudson_web/live/setup_live/credentials.ex
def handle_event("test_neon", %{"url" => url}, socket) do
  case Hudson.Sync.test_connection(url) do
    {:ok, version} ->
      {:noreply,
       socket
       |> assign(:neon_status, :success)
       |> assign(:neon_version, version)
       |> put_flash(:info, "Connected to Neon (schema v#{version})")}

    {:error, reason} ->
      {:noreply,
       socket
       |> assign(:neon_status, :error)
       |> put_flash(:error, "Connection failed: #{reason}")}
  end
end
```

## Security Considerations

### Threat Model

| Threat | Mitigation |
|--------|------------|
| Credential theft from disk | Store in OS keychain/DPAPI, never plaintext |
| Man-in-the-middle (Neon) | TLS 1.3+, verify Neon certificates |
| Binary tampering | Code sign + notarize, updater checks signatures |
| Log file secrets | Redact `DATABASE_URL`, API keys via Logger backend filter |
| Memory dumps | Use `:crypto.strong_rand_bytes` for secrets, avoid `System.put_env` |
| Malicious updates | GPG-signed release metadata, checksum verification |

### Secret Redaction

```elixir
# config/runtime.exs
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  # Add custom formatter to redact secrets
  formatters: [Hudson.LogFormatter]

# lib/hudson/log_formatter.ex
defmodule Hudson.LogFormatter do
  def format(level, message, timestamp, metadata) do
    message
    |> redact(~r/DATABASE_URL=[^\s]+/, "DATABASE_URL=***")
    |> redact(~r/sk-[a-zA-Z0-9]+/, "***")  # OpenAI keys
    |> redact(~r/shpat_[a-f0-9]+/, "***")  # Shopify tokens
  end
end
```

## Notes on Current Code Risks (to address as part of the move)
- `config/runtime.exs` currently raises on missing `DATABASE_URL`/`SECRET_KEY_BASE`, which will block first-run in desktop mode; needs the new bootstrap flow.
- Client-side migrations against Neon would be risky; shift to CI-run only.
- Credentials are presently configured via env; move to secure storage and avoid env mutation for secrets.

## Resources & References

- **Tauri Documentation:** https://tauri.app/v1/guides/
- **Burrito + Tauri Guide:** https://mrpopov.com/posts/elixir-liveview-single-binary/
- **Ecto SQLite:** https://hexdocs.pm/ecto_sqlite3
- **Phoenix Releases:** https://hexdocs.pm/phoenix/releases.html
- **Apple Notarization:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Tauri Sidecar Pattern:** https://tauri.app/v1/guides/building/sidecar/
