defmodule SocialObjects.Repo.Migrations.AddEngagementFieldsToBrandCreators do
  use Ecto.Migration

  def change do
    alter table(:brand_creators) do
      add :last_touchpoint_at, :utc_datetime
      add :last_touchpoint_type, :string
      add :preferred_contact_channel, :string
      add :next_touchpoint_at, :utc_datetime
    end

    create index(:brand_creators, [:brand_id, :next_touchpoint_at])
    create index(:brand_creators, [:brand_id, :last_touchpoint_at])
  end
end
