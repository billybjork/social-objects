defmodule SocialObjects.Repo.Migrations.ExtendProductNameLength do
  use Ecto.Migration

  def change do
    alter table(:creator_samples) do
      modify :product_name, :string, size: 500
    end
  end
end
