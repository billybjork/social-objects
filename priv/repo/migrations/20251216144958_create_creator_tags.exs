defmodule SocialObjects.Repo.Migrations.CreateCreatorTags do
  use Ecto.Migration

  def change do
    create table(:creator_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :brand_id, references(:brands, on_delete: :delete_all), null: false
      add :name, :string, size: 50, null: false
      add :color, :string, size: 20, null: false, default: "gray"
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    # Unique tag names per brand
    create unique_index(:creator_tags, [:brand_id, :name])
    create index(:creator_tags, [:brand_id])
    create index(:creator_tags, [:position])
  end
end
