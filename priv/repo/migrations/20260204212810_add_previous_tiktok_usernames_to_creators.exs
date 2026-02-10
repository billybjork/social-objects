defmodule SocialObjects.Repo.Migrations.AddPreviousTiktokUsernamesToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :previous_tiktok_usernames, {:array, :string}, default: []
    end

    # Index for looking up creators by previous handles
    create index(:creators, [:previous_tiktok_usernames], using: :gin)
  end
end
