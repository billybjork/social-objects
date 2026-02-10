defmodule SocialObjects.Repo.Migrations.AddBrandIdToTalkingPointsGenerations do
  use Ecto.Migration

  def change do
    alter table(:talking_points_generations) do
      add :brand_id, references(:brands, on_delete: :delete_all)
    end

    create index(:talking_points_generations, [:brand_id])
  end
end
