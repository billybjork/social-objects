defmodule SocialObjects.Repo.Migrations.CreateCreatorVideoMetricSnapshots do
  use Ecto.Migration

  def change do
    create table(:creator_video_metric_snapshots) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: false

      add :creator_video_id, references(:creator_videos, on_delete: :nilify_all), null: true

      add :tiktok_video_id, :string, null: false
      add :snapshot_date, :date, null: false
      add :window_days, :integer, null: false

      # Windowed metric values returned by TikTok analytics for the given window.
      add :gmv_cents, :bigint, null: false, default: 0
      add :views, :bigint, null: false, default: 0
      add :items_sold, :integer, null: false, default: 0
      add :gpm_cents, :integer
      add :ctr, :decimal

      # Correlates rows written in one sync run for observability/backfills.
      add :source_run_id, :string
      add :raw_payload, :map

      timestamps()
    end

    create unique_index(
             :creator_video_metric_snapshots,
             [:brand_id, :tiktok_video_id, :snapshot_date, :window_days],
             name: :creator_video_metric_snapshots_brand_video_date_window_idx
           )

    create index(
             :creator_video_metric_snapshots,
             [:brand_id, :window_days, :tiktok_video_id, :snapshot_date, :id],
             name: :creator_video_metric_snapshots_latest_lookup_idx
           )

    create index(:creator_video_metric_snapshots, [:creator_video_id])
  end
end
