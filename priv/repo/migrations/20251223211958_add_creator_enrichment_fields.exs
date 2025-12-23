defmodule Pavoi.Repo.Migrations.AddCreatorEnrichmentFields do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      # Identity from marketplace API
      add :tiktok_nickname, :string
      add :tiktok_avatar_url, :text
      add :tiktok_bio, :text

      # Performance metrics (cached from latest enrichment)
      add :video_gmv_cents, :bigint, default: 0
      add :live_gmv_cents, :bigint, default: 0
      add :avg_video_views, :integer
      add :video_count, :integer, default: 0
      add :live_count, :integer, default: 0

      # Enrichment tracking
      add :last_enriched_at, :utc_datetime
      add :enrichment_source, :string
    end

    # Index for finding stale creators to enrich
    create index(:creators, [:last_enriched_at])
  end
end
