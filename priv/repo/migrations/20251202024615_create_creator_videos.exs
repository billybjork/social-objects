defmodule Pavoi.Repo.Migrations.CreateCreatorVideos do
  use Ecto.Migration

  def change do
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
      add :ctr, :decimal

      # Commission
      add :est_commission_cents, :bigint

      timestamps()
    end

    create unique_index(:creator_videos, [:tiktok_video_id])
    create index(:creator_videos, [:creator_id])
    create index(:creator_videos, [:posted_at])
  end
end
