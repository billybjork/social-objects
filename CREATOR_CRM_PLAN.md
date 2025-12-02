# Creator CRM Data Model & Implementation Plan

> **Status**: Phase 1 Complete - Data Model & Import Done
> **Created**: 2025-12-01
> **Last Updated**: 2025-12-02

## Data Analysis Summary

### Source Files Analyzed

| File | Rows | Unique Creators | Key Data |
|------|------|-----------------|----------|
| All Free Sample Data | ~123K | 9,002 buyers | Order ID, Username, Recipient, Phone, Product, Address |
| Creator Data L6 Months (Refunnel) | 7,271 | 7,271 | Username, Followers, EMV, GMV, Engagement metrics |
| Creator email/phone (Euka) | 25,284 | 25,284 | Handle, Email (55% filled), Phone (16% filled), Address |
| Phone Numbers Raw Data | 36,308 | 17,370 | Username, First/Last Name, Phone |
| Video Data Last 90 Days | 59,894 | 16,728 | Video ID, Creator, GMV, Items Sold, Impressions |
| Product Analytics | 611 | N/A | TikTok Product ID, GMV, Sales by channel |

### Key Findings

**1. Primary Identifier: TikTok Username**
- All files use TikTok username as the common key
- Must normalize (lowercase, trim) for matching
- ~8,350 creators overlap between Sample Orders and Euka contact data

**2. Data Quality Issues**
- Phone numbers: Mixed formats (masked `(+1)832*****59` vs full `(+1)3159212129`)
- Duplicates in Phone Numbers file (same creator, same data repeated)
- Missing data: 45% missing email in Euka, 84% missing phone
- Some names have encoding issues (e.g., `MartÃ­nez`)

**3. Data Relationships**
```
                    ┌──────────────────┐
                    │     Creator      │
                    │  (tiktok_handle) │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐  ┌───────────────┐  ┌────────────────┐
│ Creator Samples │  │Creator Videos │  │  Performance   │
│ (what received) │  │(content made) │  │  (metrics)     │
└─────────────────┘  └───────────────┘  └────────────────┘
         │                   │
         ▼                   ▼
    ┌─────────┐        ┌─────────┐
    │ Product │        │ Product │
    └─────────┘        └─────────┘
```

**4. Estimated Total Unique Creators**
- Union of all sources: ~25-30K unique creators
- 11,807 mentioned in client doc (sampled creators)

---

## Proposed Data Model

### Core Tables

#### 1. `creators`
Central creator entity - single source of truth for creator identity.

```elixir
create table(:creators) do
  # Identity
  add :tiktok_username, :string, null: false  # Primary identifier, normalized lowercase
  add :tiktok_user_id, :string                # TikTok's internal user ID if available
  add :tiktok_profile_url, :string

  # Contact Info (aggregated from multiple sources)
  add :email, :string
  add :phone, :string                         # Normalized E.164 format
  add :phone_verified, :boolean, default: false  # True if we have full (non-masked) number
  add :first_name, :string
  add :last_name, :string

  # Address (for shipping samples)
  add :address_line_1, :string
  add :address_line_2, :string
  add :city, :string
  add :state, :string
  add :zipcode, :string
  add :country, :string, default: "US"

  # TikTok Shop Creator Badge (official tiers based on monthly GMV)
  # Values: "bronze", "silver", "gold", "platinum", "ruby", "emerald", "sapphire", "diamond"
  add :tiktok_badge_level, :string

  # Internal classification
  add :is_whitelisted, :boolean, default: false
  add :tags, {:array, :string}, default: []
  add :notes, :text

  # Current metrics (latest snapshot)
  add :follower_count, :integer
  add :total_gmv_cents, :bigint, default: 0
  add :total_videos, :integer, default: 0

  timestamps()
end

create unique_index(:creators, [:tiktok_username])
create index(:creators, [:email])
create index(:creators, [:phone])
create index(:creators, [:tiktok_badge_level])
```

#### 2. `brand_creators` (Multi-brand Support)
Junction table linking creators to brands they work with.

```elixir
create table(:brand_creators) do
  add :brand_id, references(:brands, on_delete: :delete_all), null: false
  add :creator_id, references(:creators, on_delete: :delete_all), null: false

  # Brand-specific creator status
  add :status, :string, default: "active"     # "active", "inactive", "blocked"
  add :joined_at, :utc_datetime
  add :notes, :text

  timestamps()
end

create unique_index(:brand_creators, [:brand_id, :creator_id])
create index(:brand_creators, [:creator_id])
```

#### 3. `creator_samples`
Tracks products sampled to creators (free product orders).

```elixir
create table(:creator_samples) do
  add :creator_id, references(:creators, on_delete: :restrict), null: false
  add :brand_id, references(:brands, on_delete: :restrict), null: false  # Multi-brand support
  add :product_id, references(:products, on_delete: :restrict)  # Link to existing products

  # TikTok Order Info
  add :tiktok_order_id, :string
  add :tiktok_sku_id, :string
  add :product_name, :string                  # Snapshot at time of sample
  add :variation, :string
  add :quantity, :integer, default: 1

  # Timing
  add :ordered_at, :utc_datetime
  add :shipped_at, :utc_datetime
  add :delivered_at, :utc_datetime

  # Status
  add :status, :string                        # "pending", "shipped", "delivered", "cancelled"

  timestamps()
end

create index(:creator_samples, [:creator_id])
create index(:creator_samples, [:brand_id])
create index(:creator_samples, [:product_id])
create unique_index(:creator_samples, [:tiktok_order_id, :tiktok_sku_id])
```

#### 4. `creator_videos`
Content created by creators (primarily for tracking affiliate performance).

```elixir
create table(:creator_videos) do
  add :creator_id, references(:creators, on_delete: :restrict), null: false

  # Video Identity
  add :tiktok_video_id, :string, null: false
  add :video_url, :string
  add :title, :text

  # Timing
  add :posted_at, :utc_datetime

  # Performance Metrics
  add :gmv_cents, :bigint, default: 0
  add :items_sold, :integer, default: 0
  add :affiliate_orders, :integer, default: 0
  add :impressions, :integer, default: 0
  add :likes, :integer, default: 0
  add :comments, :integer, default: 0
  add :shares, :integer, default: 0
  add :ctr, :decimal                          # Click-through rate

  # Commission
  add :est_commission_cents, :bigint

  timestamps()
end

create unique_index(:creator_videos, [:tiktok_video_id])
create index(:creator_videos, [:creator_id])
create index(:creator_videos, [:posted_at])
```

#### 5. `creator_video_products`
Junction table linking videos to products they promote.

```elixir
create table(:creator_video_products) do
  add :creator_video_id, references(:creator_videos, on_delete: :delete_all), null: false
  add :product_id, references(:products, on_delete: :restrict)
  add :tiktok_product_id, :string             # For matching when product not in DB

  timestamps()
end

create unique_index(:creator_video_products, [:creator_video_id, :product_id])
```

#### 6. `creator_performance_snapshots`
Point-in-time snapshots of creator metrics (for historical tracking).

```elixir
create table(:creator_performance_snapshots) do
  add :creator_id, references(:creators, on_delete: :delete_all), null: false
  add :snapshot_date, :date, null: false
  add :source, :string                        # "refunnel", "tiktok_api", "manual"

  # Metrics
  add :follower_count, :integer
  add :gmv_cents, :bigint
  add :emv_cents, :bigint                     # Earned Media Value
  add :total_posts, :integer
  add :total_likes, :integer
  add :total_comments, :integer
  add :total_shares, :integer
  add :total_impressions, :bigint
  add :engagement_count, :integer

  timestamps()
end

create unique_index(:creator_performance_snapshots, [:creator_id, :snapshot_date, :source])
create index(:creator_performance_snapshots, [:snapshot_date])
```

#### 7. `creator_communications` (Future - for Mailgun/Twilio integration)
```elixir
create table(:creator_communications) do
  add :creator_id, references(:creators, on_delete: :restrict), null: false

  add :channel, :string, null: false          # "email", "sms", "tiktok_dm"
  add :direction, :string                     # "outbound", "inbound"
  add :status, :string                        # "sent", "delivered", "failed", "opened", "replied"
  add :subject, :string
  add :body, :text
  add :external_id, :string                   # Mailgun/Twilio message ID

  add :sent_at, :utc_datetime
  add :delivered_at, :utc_datetime
  add :opened_at, :utc_datetime

  timestamps()
end

create index(:creator_communications, [:creator_id])
create index(:creator_communications, [:channel])
create index(:creator_communications, [:sent_at])
```

---

## Import Strategy

### Phase 1: Initial Data Load

Order of operations (respects foreign key dependencies):

1. **Import Creators** (merge from multiple sources)
   - Start with Euka data (largest contact dataset)
   - Merge in Phone Numbers data (additional phones, names)
   - Merge in Refunnel data (performance metrics, profile URLs)
   - Merge in Sample Order buyers (any new creators + addresses)

2. **Import Creator Samples**
   - From "All Free Sample Data"
   - Match products to existing products table via SKU or TikTok Product ID
   - Create `creator_samples` records

3. **Import Creator Videos**
   - From "Video Data Last 90 Days"
   - Link to creators by username

4. **Import Performance Snapshots**
   - From "Creator Data L6 Months (Refunnel)"
   - One snapshot per creator

### Deduplication & Merge Logic

```elixir
# Pseudocode for creator upsert
def upsert_creator(attrs) do
  normalized_username = String.downcase(String.trim(attrs.tiktok_username))

  case Repo.get_by(Creator, tiktok_username: normalized_username) do
    nil ->
      # Insert new creator
      %Creator{} |> Creator.changeset(attrs) |> Repo.insert()

    existing ->
      # Merge: only fill in missing fields, don't overwrite existing data
      merged = merge_creator_attrs(existing, attrs)
      existing |> Creator.changeset(merged) |> Repo.update()
  end
end

defp merge_creator_attrs(existing, new) do
  %{
    email: existing.email || new[:email],
    phone: existing.phone || normalize_phone(new[:phone]),
    first_name: existing.first_name || new[:first_name],
    # ... etc
  }
end
```

---

## Design Decisions (Resolved)

### 1. Creator Tiers: TikTok Shop Creator Badge System
TikTok has an official Creator Badge system based on **monthly GMV** (not followers):

| Badge | GMV Range (Monthly) |
|-------|---------------------|
| Bronze | Entry level |
| Silver | $1K - $5K |
| Gold | $5K+ (estimated) |
| Platinum | Higher |
| Ruby | Higher |
| Emerald | Higher |
| Sapphire | Higher |
| Diamond | Top tier |

Source: [TikTok Seller University - Creator Badges](https://seller-us.tiktok.com/university/essay?knowledge_id=1082957398361902&lang=en)

**Implementation**: Store as enum/string field `tiktok_badge_level` with these values. Can sync from TikTok API when available.

### 2. Phone Number Strategy: Merge/Match
- Store all phone numbers (including masked)
- Normalize to E.164 format where possible
- During import, attempt to match masked numbers with full numbers from other sources
- Add `phone_verified` boolean to track data quality

### 3. Multi-Brand Support: Yes
- Add `brand_id` foreign key to `creators` table
- A creator can exist across multiple brands (many-to-many via join table)
- Sample data is brand-specific

### 4. Development Approach: Parallel
- Build data model and import workers
- Build basic CRM UI simultaneously
- Import data as UI becomes available to view it

---

## Implementation Phases

### Phase 1: Data Model & Initial Import ✅ COMPLETE (2025-12-02)
- [x] Create migrations for new tables (6 migrations)
- [x] Create Ecto schemas (lib/pavoi/creators/ context)
- [x] Build CSV import workers (Oban jobs)
- [x] Run initial data import

**Import Results (Local Dev DB):**
| Data Type | Records |
|-----------|---------|
| Creators | 36,876 |
| Samples | 24,603 |
| Videos | 59,834 |
| Performance Snapshots | 7,272 |
| Brand-Creator Links | 9,001 |

**Files Created:**
- `lib/pavoi/creators.ex` - Context module
- `lib/pavoi/creators/creator.ex` - Creator schema
- `lib/pavoi/creators/brand_creator.ex` - Brand-Creator junction
- `lib/pavoi/creators/creator_sample.ex` - Sample tracking
- `lib/pavoi/creators/creator_video.ex` - Video performance
- `lib/pavoi/creators/creator_video_product.ex` - Video-Product junction
- `lib/pavoi/creators/creator_performance_snapshot.ex` - Historical metrics
- `lib/pavoi/workers/creator_import_worker.ex` - CSV import worker
- 6 migrations in `priv/repo/migrations/`

### Phase 2: Basic CRM UI
- [ ] Creator list view with search/filter
- [ ] Creator detail view (contact info, samples, videos)
- [ ] Manual creator editing

### Phase 3: Analytics Dashboard
- [ ] Creator performance metrics
- [ ] Sample tracking dashboard
- [ ] Video performance by creator

### Phase 4: Communication Integrations
- [ ] Mailgun email sending
- [ ] Twilio SMS sending
- [ ] Communication history logging

### Phase 5: Ongoing Sync
- [ ] TikTok Shop API integration for affiliate data
- [ ] Scheduled sync workers
- [ ] Webhook handlers for real-time updates

---

## Files to Create/Modify

### New Files (Schemas & Context)
- `lib/pavoi/creators.ex` - Context module (CRUD, search, import logic)
- `lib/pavoi/creators/creator.ex` - Creator schema
- `lib/pavoi/creators/brand_creator.ex` - Brand-Creator junction schema
- `lib/pavoi/creators/creator_sample.ex` - Sample tracking schema
- `lib/pavoi/creators/creator_video.ex` - Video performance schema
- `lib/pavoi/creators/creator_video_product.ex` - Video-Product junction schema
- `lib/pavoi/creators/creator_performance_snapshot.ex` - Historical metrics schema

### New Files (Workers)
- `lib/pavoi/workers/creator_import_worker.ex` - Oban worker for CSV imports
- `lib/pavoi/workers/creator_euka_import_worker.ex` - Import from Euka CSV
- `lib/pavoi/workers/creator_sample_import_worker.ex` - Import from Sample Orders CSV
- `lib/pavoi/workers/creator_video_import_worker.ex` - Import from Video Data CSV
- `lib/pavoi/workers/creator_refunnel_import_worker.ex` - Import from Refunnel CSV

### New Files (LiveViews)
- `lib/pavoi_web/live/creators_live/index.ex` - Creator list with search/filter
- `lib/pavoi_web/live/creators_live/show.ex` - Creator detail view

### New Files (Migrations)
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_creators.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_brand_creators.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_creator_samples.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_creator_videos.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_creator_video_products.exs`
- `priv/repo/migrations/YYYYMMDDHHMMSS_create_creator_performance_snapshots.exs`

### Modify
- `lib/pavoi_web/router.ex` - Add /creators routes
- `lib/pavoi_web/components/layouts/app.html.heex` - Add Creators nav link
