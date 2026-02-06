defmodule Pavoi.Repo.Migrations.AddIsAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
    end

    # Partial index for efficient admin lookups
    create index(:users, [:is_admin], where: "is_admin = true")
  end
end
