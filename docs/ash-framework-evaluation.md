# Ash Framework Evaluation for Social Objects

**Date:** 2026-02-20
**Recommendation:** Do not adopt

## Summary

The Ash framework is a declarative, resource-oriented backend framework for Elixir that excels at reducing CRUD boilerplate, auto-generating APIs (REST/GraphQL), and providing built-in authorization policies. After evaluating it against the current codebase, **the costs of adoption significantly outweigh the benefits**.

## Current Architecture

Social Objects is a Phoenix 1.8 + LiveView 1.1 application serving as a TikTok Shop creator/affiliate CRM. Key characteristics:

- **8,100+ lines** across 6 context modules (Creators, Catalog, ProductSets, Outreach, TiktokShop, TiktokLive)
- **122 database migrations** — a mature, evolved schema
- **24 Oban background workers** for syncing with TikTok, Shopify, BigQuery, SendGrid, and OpenAI
- **LiveView-only UI** — no REST or GraphQL API layer
- **Multi-tenant** brand-scoped architecture with role-based access control
- Well-organized Phoenix contexts with consistent type specs and conventions

## Where Ash Excels (Low Relevance Here)

| Ash Strength | Relevance |
|---|---|
| Auto-generated REST/GraphQL APIs | **None** — LiveView-only app, no API consumers |
| Declarative CRUD resource definitions | **Low** — most code is search, filtering, analytics, and sync logic, not CRUD |
| Built-in pagination & filtering | **Low** — already implemented and stable across all contexts |
| Authorization policies | **Low** — already handled via `brand_permissions.ex`, `brand_auth.ex`, `admin_auth.ex` |
| Reducing boilerplate | **Low** — the boilerplate is already written, tested, and working |

## Why Ash Is a Poor Fit

### 1. Core complexity is integration-heavy, not data-model-heavy

The heart of this application is its 24 Oban workers that:
- Capture TikTok live streams via WebSocket + protobuf
- Sync product catalogs from Shopify's GraphQL API
- Pull creator metrics from TikTok Shop API (batched with rate limiting)
- Export order data to/from BigQuery
- Generate AI content via OpenAI
- Send and track email campaigns via SendGrid

These are inherently imperative, side-effect-driven operations. Ash's declarative resource model doesn't simplify any of them.

### 2. Large context modules aren't CRUD boilerplate

`creators.ex` (3,569 lines) is dominated by:
- Complex search/filter/sort pipelines with composable Ecto queries
- CSV export logic
- Engagement ranking calculations
- Import audit trails and enrichment workflows
- Multi-source data reconciliation

Ash resources wouldn't absorb this complexity — it would still need to be written as custom actions, losing the clarity and debuggability of plain Ecto queries.

### 3. Migration cost is prohibitive for a mature application

Rewriting every context module, Ecto schema, changeset, and LiveView integration to use Ash resources would be a near-total rewrite of the business logic layer. With 122 migrations and a production system serving real users, this risk is unjustifiable without a clear business benefit.

### 4. LiveView integration adds friction

The existing LiveViews have complex interactive behaviors (2,238 lines in `creators_live/index.ex` alone). AshPhoenix would add another abstraction layer between LiveView and data queries without simplifying the custom UI logic — product set state machines, real-time PubSub synchronization, voice control integration, etc.

### 5. Steep learning curve with no payoff

The team is already productive with standard Phoenix conventions. Ash's DSL, extension system, and resource lifecycle model would require significant ramp-up time for a paradigm shift that doesn't address the actual pain points of the codebase.

## When Ash Would Have Made Sense

- **Greenfield project** with straightforward CRUD-heavy domains
- **Multi-format API exposure** needed (REST + GraphQL simultaneously)
- **Data-model-centric** domain with less external integration complexity
- **Growing authorization complexity** beyond what manual plugs can handle
- **Multiple data sources** that benefit from Ash's unified resource abstraction

## Recommended Alternatives

If context module size becomes a maintenance concern, these targeted improvements would deliver more value:

1. **Split large contexts into submodules** — e.g., `Creators.Search`, `Creators.Import`, `Creators.Analytics`, `Creators.Enrichment`
2. **Extract shared pagination/filtering** into a small utility module reused across contexts
3. **Add query builder helpers** for the composable filter patterns repeated in `creators.ex` and `product_sets.ex`

These are incremental, low-risk changes that build on existing patterns rather than replacing them.
