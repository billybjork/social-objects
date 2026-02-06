defmodule Pavoi.Repo.Migrations.AddBrandIdToTiktokLiveTables do
  use Ecto.Migration

  def up do
    alter table(:tiktok_streams) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:tiktok_comments) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:tiktok_stream_stats) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    execute """
    UPDATE tiktok_streams
    SET brand_id = sub.brand_id
    FROM (
      SELECT ps.id AS product_set_id, ps.brand_id AS brand_id
      FROM product_sets ps
    ) AS sub
    WHERE tiktok_streams.product_set_id = sub.product_set_id
      AND tiktok_streams.brand_id IS NULL;
    """

    execute """
    UPDATE tiktok_streams
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    execute """
    UPDATE tiktok_comments c
    SET brand_id = s.brand_id
    FROM tiktok_streams s
    WHERE c.stream_id = s.id
      AND c.brand_id IS NULL;
    """

    execute """
    UPDATE tiktok_stream_stats ss
    SET brand_id = s.brand_id
    FROM tiktok_streams s
    WHERE ss.stream_id = s.id
      AND ss.brand_id IS NULL;
    """

    alter table(:tiktok_streams) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:tiktok_comments) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:tiktok_stream_stats) do
      modify :brand_id, :bigint, null: false
    end

    create index(:tiktok_streams, [:brand_id])
    create index(:tiktok_comments, [:brand_id])
    create index(:tiktok_stream_stats, [:brand_id])
  end

  def down do
    drop_if_exists index(:tiktok_streams, [:brand_id])
    drop_if_exists index(:tiktok_comments, [:brand_id])
    drop_if_exists index(:tiktok_stream_stats, [:brand_id])

    alter table(:tiktok_streams) do
      remove :brand_id
    end

    alter table(:tiktok_comments) do
      remove :brand_id
    end

    alter table(:tiktok_stream_stats) do
      remove :brand_id
    end
  end
end
