defmodule SocialObjects.Repo.Migrations.AddAvatarStorageKeyToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :tiktok_avatar_storage_key, :string
    end
  end
end
