defmodule Pavoi.Repo.Migrations.CreateBrandInvites do
  use Ecto.Migration

  def change do
    create table(:brand_invites) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: false
      add :invited_by_user_id, references(:users, on_delete: :nilify_all)
      add :email, :string, null: false
      add :role, :string, null: false, default: "viewer"
      add :expires_at, :utc_datetime
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:brand_invites, [:brand_id])
    create index(:brand_invites, [:email])
    create index(:brand_invites, [:invited_by_user_id])
    create unique_index(:brand_invites, [:brand_id, :email])
  end
end
