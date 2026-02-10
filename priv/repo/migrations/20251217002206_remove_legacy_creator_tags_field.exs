defmodule SocialObjects.Repo.Migrations.RemoveLegacyCreatorTagsField do
  use Ecto.Migration

  def change do
    drop_if_exists index(:creators, [:tags], using: :gin)

    alter table(:creators) do
      remove :tags, {:array, :string}, default: []
    end
  end
end
