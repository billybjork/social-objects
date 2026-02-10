defmodule SocialObjects.Repo.Migrations.AddIndexToCreatorsTiktokUserId do
  use Ecto.Migration

  def change do
    # Add index for faster lookup by tiktok_user_id
    # Used by get_creator_by_tiktok_user_id/1 for matching in BigQuery sync
    create index(:creators, [:tiktok_user_id])
  end
end
