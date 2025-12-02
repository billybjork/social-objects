defmodule Pavoi.Repo.Migrations.CreateCreatorPerformanceSnapshots do
  use Ecto.Migration

  def change do
    create table(:creator_performance_snapshots) do
      add :creator_id, references(:creators, on_delete: :delete_all), null: false
      add :snapshot_date, :date, null: false
      add :source, :string

      # Metrics
      add :follower_count, :integer
      add :gmv_cents, :bigint
      add :emv_cents, :bigint
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
  end
end
