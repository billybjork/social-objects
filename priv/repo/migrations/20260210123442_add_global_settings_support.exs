defmodule SocialObjects.Repo.Migrations.AddGlobalSettingsSupport do
  use Ecto.Migration

  def change do
    alter table(:system_settings) do
      modify :brand_id, :bigint, null: true, from: {:bigint, null: false}
    end

    # Partial unique index for global settings (where brand_id IS NULL)
    create unique_index(:system_settings, [:key],
             where: "brand_id IS NULL",
             name: :system_settings_global_key_unique
           )
  end
end
