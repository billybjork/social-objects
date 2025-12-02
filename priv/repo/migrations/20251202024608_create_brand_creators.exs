defmodule Pavoi.Repo.Migrations.CreateBrandCreators do
  use Ecto.Migration

  def change do
    create table(:brand_creators) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: false
      add :creator_id, references(:creators, on_delete: :delete_all), null: false

      # Brand-specific creator status
      add :status, :string, default: "active"
      add :joined_at, :utc_datetime
      add :notes, :text

      timestamps()
    end

    create unique_index(:brand_creators, [:brand_id, :creator_id])
    create index(:brand_creators, [:creator_id])
  end
end
