defmodule Pavoi.Repo.Migrations.AddCumulativeGmvTracking do
  use Ecto.Migration

  def change do
    # Add cumulative GMV tracking fields to creators
    alter table(:creators) do
      add :cumulative_gmv_cents, :bigint, default: 0
      add :cumulative_video_gmv_cents, :bigint, default: 0
      add :cumulative_live_gmv_cents, :bigint, default: 0
      add :gmv_tracking_started_at, :date
    end

    # Add delta fields to performance snapshots for audit trail
    alter table(:creator_performance_snapshots) do
      add :gmv_delta_cents, :bigint
      add :video_gmv_delta_cents, :bigint
      add :live_gmv_delta_cents, :bigint
    end

    # Index for efficient sorting by cumulative GMV
    create index(:creators, [:cumulative_gmv_cents])
  end
end
