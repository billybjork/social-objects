defmodule SocialObjects.Repo.Migrations.CreateCreatorVideoProducts do
  use Ecto.Migration

  def change do
    create table(:creator_video_products) do
      add :creator_video_id, references(:creator_videos, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict)
      add :tiktok_product_id, :string

      timestamps()
    end

    create unique_index(:creator_video_products, [:creator_video_id, :product_id],
             where: "product_id IS NOT NULL"
           )

    create index(:creator_video_products, [:product_id])
  end
end
