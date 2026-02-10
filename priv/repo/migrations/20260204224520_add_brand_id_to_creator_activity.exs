defmodule SocialObjects.Repo.Migrations.AddBrandIdToCreatorActivity do
  use Ecto.Migration

  def up do
    alter table(:creator_videos) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:creator_performance_snapshots) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:creator_purchases) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:outreach_logs) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    execute """
    UPDATE creator_videos
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    execute """
    UPDATE creator_performance_snapshots
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    execute """
    UPDATE creator_purchases
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    execute """
    UPDATE outreach_logs
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    alter table(:creator_videos) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:creator_performance_snapshots) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:creator_purchases) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:outreach_logs) do
      modify :brand_id, :bigint, null: false
    end

    create index(:creator_videos, [:brand_id])
    create index(:creator_performance_snapshots, [:brand_id])
    create index(:creator_purchases, [:brand_id])
    create index(:outreach_logs, [:brand_id])
  end

  def down do
    drop_if_exists index(:creator_videos, [:brand_id])
    drop_if_exists index(:creator_performance_snapshots, [:brand_id])
    drop_if_exists index(:creator_purchases, [:brand_id])
    drop_if_exists index(:outreach_logs, [:brand_id])

    alter table(:creator_videos) do
      remove :brand_id
    end

    alter table(:creator_performance_snapshots) do
      remove :brand_id
    end

    alter table(:creator_purchases) do
      remove :brand_id
    end

    alter table(:outreach_logs) do
      remove :brand_id
    end
  end
end
