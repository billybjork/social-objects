defmodule SocialObjects.Repo.Migrations.CreateCreators do
  use Ecto.Migration

  def change do
    create table(:creators) do
      # Identity
      add :tiktok_username, :string, null: false
      add :tiktok_user_id, :string
      add :tiktok_profile_url, :string

      # Contact Info
      add :email, :string
      add :phone, :string
      add :phone_verified, :boolean, default: false
      add :first_name, :string
      add :last_name, :string

      # Address
      add :address_line_1, :string
      add :address_line_2, :string
      add :city, :string
      add :state, :string
      add :zipcode, :string
      add :country, :string, default: "US"

      # TikTok Shop Creator Badge
      # Values: "bronze", "silver", "gold", "platinum", "ruby", "emerald", "sapphire", "diamond"
      add :tiktok_badge_level, :string

      # Internal classification
      add :is_whitelisted, :boolean, default: false
      add :tags, {:array, :string}, default: []
      add :notes, :text

      # Current metrics (latest snapshot)
      add :follower_count, :integer
      add :total_gmv_cents, :bigint, default: 0
      add :total_videos, :integer, default: 0

      timestamps()
    end

    create unique_index(:creators, [:tiktok_username])
    create index(:creators, [:email])
    create index(:creators, [:phone])
    create index(:creators, [:tiktok_badge_level])
    create index(:creators, [:tags], using: :gin)
  end
end
