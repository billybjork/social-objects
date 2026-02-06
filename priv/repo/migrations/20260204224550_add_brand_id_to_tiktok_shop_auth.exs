defmodule Pavoi.Repo.Migrations.AddBrandIdToTiktokShopAuth do
  use Ecto.Migration

  def up do
    alter table(:tiktok_shop_auth) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    execute """
    UPDATE tiktok_shop_auth
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    alter table(:tiktok_shop_auth) do
      modify :brand_id, :bigint, null: false
    end

    drop_if_exists index(:tiktok_shop_auth, [:id])
    create unique_index(:tiktok_shop_auth, [:brand_id])
  end

  def down do
    drop_if_exists index(:tiktok_shop_auth, [:brand_id])

    create unique_index(:tiktok_shop_auth, [:id])

    alter table(:tiktok_shop_auth) do
      remove :brand_id
    end
  end
end
