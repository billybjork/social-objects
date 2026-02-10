defmodule SocialObjects.Repo.Migrations.AddSnapshotGmvBreakdown do
  use Ecto.Migration

  def change do
    alter table(:creator_performance_snapshots) do
      add :video_gmv_cents, :bigint
      add :live_gmv_cents, :bigint
      add :avg_video_views, :integer
    end
  end
end
