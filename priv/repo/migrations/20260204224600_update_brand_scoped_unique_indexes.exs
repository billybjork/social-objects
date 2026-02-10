defmodule SocialObjects.Repo.Migrations.UpdateBrandScopedUniqueIndexes do
  use Ecto.Migration

  def up do
    drop_if_exists index(:products, [:pid])

    create unique_index(:products, [:brand_id, :pid],
             where: "pid IS NOT NULL",
             name: :products_brand_id_pid_index
           )

    drop_if_exists index(:products, [:tiktok_product_id],
                     name: :products_tiktok_product_id_unique_index
                   )

    create unique_index(:products, [:brand_id, :tiktok_product_id],
             where: "tiktok_product_id IS NOT NULL",
             name: :products_brand_id_tiktok_product_id_index
           )

    drop_if_exists index(:product_sets, [:slug], name: :sessions_slug_index)

    create unique_index(:product_sets, [:brand_id, :slug],
             name: :product_sets_brand_id_slug_index
           )

    drop_if_exists index(:tiktok_streams, [:room_id],
                     name: :tiktok_streams_room_id_capturing_unique
                   )

    create unique_index(:tiktok_streams, [:brand_id, :room_id],
             where: "status = 'capturing'",
             name: :tiktok_streams_brand_room_capturing_unique
           )
  end

  def down do
    drop_if_exists index(:products, [:brand_id, :pid], name: :products_brand_id_pid_index)
    create unique_index(:products, [:pid], where: "pid IS NOT NULL")

    drop_if_exists index(:products, [:brand_id, :tiktok_product_id],
                     name: :products_brand_id_tiktok_product_id_index
                   )

    create unique_index(:products, [:tiktok_product_id],
             where: "tiktok_product_id IS NOT NULL",
             name: :products_tiktok_product_id_unique_index
           )

    drop_if_exists index(:product_sets, [:brand_id, :slug],
                     name: :product_sets_brand_id_slug_index
                   )

    create unique_index(:product_sets, [:slug], name: :sessions_slug_index)

    drop_if_exists index(:tiktok_streams, [:brand_id, :room_id],
                     name: :tiktok_streams_brand_room_capturing_unique
                   )

    create unique_index(:tiktok_streams, [:room_id],
             where: "status = 'capturing'",
             name: :tiktok_streams_room_id_capturing_unique
           )
  end
end
