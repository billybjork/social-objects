defmodule SocialObjects.Repo.Migrations.CreateUserBrands do
  use Ecto.Migration

  def change do
    create table(:user_brands) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :brand_id, references(:brands, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "viewer"

      timestamps()
    end

    create index(:user_brands, [:user_id])
    create index(:user_brands, [:brand_id])
    create unique_index(:user_brands, [:user_id, :brand_id])
  end
end
