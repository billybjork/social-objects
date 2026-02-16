# Social Objects

Phoenix LiveView app for TikTok live streaming sessions. Real-time product catalog with keyboard-driven navigation and synchronized host/controller views.

## Setup

```bash
mix deps.get
cp .env.example .env
# Edit .env with your DATABASE_URL (or leave unset for local postgres)
mix ecto.create && mix ecto.migrate
mix run priv/repo/seeds.exs
mix assets.build
mix phx.server
```

Visit: **http://localhost:4000/sessions/1/controller**

## Controls

**Keyboard:**
- **Type number + Enter**: Jump directly to product (e.g., "23" → Enter)
- **↓ / ↑ / Space**: Navigate products
- **← / →**: Navigate images

**Voice Control:**
- **Ctrl/Cmd + M**: Toggle voice recognition
- **Say product numbers**: "twenty three", "product 12", etc.
- 100% local processing (Whisper.js + Silero VAD)

See [VOICE_CONTROL_PLAN.md](VOICE_CONTROL_PLAN.md) for complete documentation.

## Production (Railway)

Deployments are automated via GitHub Actions on push to `main`:
- **Main app**: `.github/workflows/deploy-main.yml`
- **TikTok Bridge**: `.github/workflows/deploy-tiktok-bridge.yml`

### Manual Deployment

```bash
railway login && railway link
railway up --service pavoi        # Main app
railway up --service tiktok-bridge  # TikTok Bridge (from services/tiktok-bridge/)
```

### Environment Variables

Set `SITE_PASSWORD` to enable password protection.
