# Creator CRM Implementation Plan

> **Status**: Phase 4 Complete - Outreach Automation Done
> **Last Updated**: 2025-12-09

---

## Completed Phases

### Phase 1: Data Model & Initial Import ✅

Created database schema with 6 tables:
- `creators` - Central entity with contact info, metrics, classification
- `brand_creators` - Many-to-many junction linking creators to brands
- `creator_samples` - Tracks free product samples sent
- `creator_videos` - TikTok video performance data
- `creator_video_products` - Links videos to products
- `creator_performance_snapshots` - Historical metrics
- `outreach_logs` - Communication delivery tracking

### Phase 2: Basic CRM UI ✅

- Creator list view (`/creators`) with search, badge/brand filters, sortable columns
- Creator detail view (`/creators/:id`) with contact info, stats, tabbed sections
- Manual creator editing (contact info, notes, whitelisted status)
- Samples, Videos, and Performance history tabs

### Phase 3: Creator Outreach Automation ✅

Automated welcome communications to new creators:

**Infrastructure:**
- Mailgun email integration (`lib/pavoi/communications/mailgun.ex`)
- Twilio SMS integration (`lib/pavoi/communications/twilio.ex`)
- Message templates (`lib/pavoi/communications/templates.ex`)
- Outreach context (`lib/pavoi/outreach.ex`)
- Background worker (`lib/pavoi/workers/creator_outreach_worker.ex`)

**UI (`/outreach`):**
- Tab navigation: Pending | Sent | Skipped
- Bulk selection and approval workflow
- Send modal with Lark invite URL input
- Stats dashboard (pending, sent, today counts)

**Workflow:**
1. BigQuery sync creates new creators with `outreach_status = "pending"`
2. Review pending creators on `/outreach` page
3. Select creators and click "Send Welcome"
4. Worker sends email (+ SMS if consented) with Lark community invite
5. Results logged to `outreach_logs`, creator marked as "sent"

---

## Remaining Work

### Phase 4: Analytics Dashboard

- [ ] Creator performance metrics aggregation (top performers, trending)
- [ ] Sample tracking dashboard (conversion rates: samples → videos)
- [ ] Video performance by creator
- [ ] Export functionality (CSV download)

### Phase 5: Ongoing Sync

- [ ] TikTok Shop API integration for affiliate/creator data
- [ ] Scheduled sync workers for video performance updates
- [ ] Webhook handlers for real-time order updates (if available)

### Phase 6: Enhancements (Optional)

- [ ] Outreach history view per creator (slideout showing past communications)
- [ ] SMS consent capture via email link
- [ ] Template customization UI in settings
- [ ] Email delivery status webhooks (bounces, opens, clicks)

---

## Environment Variables Required

```bash
# BigQuery (existing)
BIGQUERY_PROJECT_ID=
BIGQUERY_SERVICE_ACCOUNT_EMAIL=
BIGQUERY_PRIVATE_KEY=

# Mailgun
MAILGUN_API_KEY=key-xxx
MAILGUN_DOMAIN=mg.yourdomain.com
MAILGUN_FROM_EMAIL=hello@yourdomain.com
MAILGUN_FROM_NAME=Pavoi

# Twilio
TWILIO_ACCOUNT_SID=ACxxx
TWILIO_AUTH_TOKEN=xxx
TWILIO_FROM_NUMBER=+15551234567
```

---

## Database Schema Reference

| Table | Purpose |
|-------|---------|
| `creators` | Central creator entity with contact info, metrics, outreach status |
| `brand_creators` | Many-to-many junction linking creators to brands |
| `creator_samples` | Tracks free product samples sent to creators |
| `creator_videos` | TikTok video performance data |
| `creator_video_products` | Links videos to products they promote |
| `creator_performance_snapshots` | Historical metrics from Refunnel etc. |
| `outreach_logs` | Email/SMS delivery tracking per creator |

### Key Fields on `creators`
- `tiktok_username` - Primary identifier (normalized lowercase)
- `tiktok_badge_level` - Official TikTok badge tier
- `is_whitelisted` - Internal VIP flag
- `outreach_status` - pending | approved | sent | skipped
- `outreach_sent_at` - When welcome was sent
- `sms_consent` / `sms_consent_at` - SMS opt-in tracking
