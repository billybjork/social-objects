defmodule SocialObjects.Repo.Migrations.UpdateCreatorPerformanceSnapshotUniqueIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(:creator_performance_snapshots, [:creator_id, :snapshot_date, :source])
    )

    create unique_index(
             :creator_performance_snapshots,
             [:brand_id, :creator_id, :snapshot_date, :source],
             name: :creator_perf_snapshots_brand_creator_date_source_idx
           )
  end
end
