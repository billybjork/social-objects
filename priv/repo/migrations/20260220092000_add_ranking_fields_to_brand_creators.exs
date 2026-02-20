defmodule SocialObjects.Repo.Migrations.AddRankingFieldsToBrandCreators do
  use Ecto.Migration

  def change do
    alter table(:brand_creators) do
      add :is_vip, :boolean, default: false, null: false
      add :is_trending, :boolean, default: false, null: false
      add :l30d_rank, :integer
      add :l90d_rank, :integer
      add :l30d_gmv_cents, :bigint
      add :stability_score, :integer
      add :engagement_priority, :string
      add :vip_locked, :boolean, default: false, null: false
    end

    create index(:brand_creators, [:brand_id, :is_vip])
    create index(:brand_creators, [:brand_id, :is_trending])
    create index(:brand_creators, [:brand_id, :engagement_priority])
    create index(:brand_creators, [:brand_id, :l30d_rank])
    create index(:brand_creators, [:brand_id, :l90d_rank])
  end
end
