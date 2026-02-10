defmodule SocialObjects.Repo.Migrations.CreateCreatorSamples do
  use Ecto.Migration

  def change do
    create table(:creator_samples) do
      add :creator_id, references(:creators, on_delete: :restrict), null: false
      add :brand_id, references(:brands, on_delete: :restrict), null: false
      add :product_id, references(:products, on_delete: :restrict)

      # TikTok Order Info
      add :tiktok_order_id, :string
      add :tiktok_sku_id, :string
      add :product_name, :string
      add :variation, :string
      add :quantity, :integer, default: 1

      # Timing
      add :ordered_at, :utc_datetime
      add :shipped_at, :utc_datetime
      add :delivered_at, :utc_datetime

      # Status: "pending", "shipped", "delivered", "cancelled"
      add :status, :string

      timestamps()
    end

    create index(:creator_samples, [:creator_id])
    create index(:creator_samples, [:brand_id])
    create index(:creator_samples, [:product_id])

    create unique_index(:creator_samples, [:tiktok_order_id, :tiktok_sku_id],
             where: "tiktok_order_id IS NOT NULL AND tiktok_sku_id IS NOT NULL"
           )
  end
end
