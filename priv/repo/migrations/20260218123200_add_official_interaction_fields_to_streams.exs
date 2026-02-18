defmodule SocialObjects.Repo.Migrations.AddOfficialInteractionFieldsToStreams do
  use Ecto.Migration

  def change do
    alter table(:tiktok_streams) do
      add :official_likes, :integer
      add :official_comments, :integer
      add :official_shares, :integer
      add :official_new_followers, :integer
      add :official_unique_viewers, :integer
      add :official_avg_price_cents, :integer
      add :official_created_sku_orders, :integer
      add :official_products_sold_count, :integer
      add :official_products_added, :integer
    end
  end
end
