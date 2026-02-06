defmodule Pavoi.Repo.Migrations.AddBrandIdToSystemSettings do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE system_settings DROP CONSTRAINT IF EXISTS system_settings_brand_id_fkey")

    alter table(:system_settings) do
      add :brand_id, references(:brands, on_delete: :delete_all)
    end

    execute("""
    UPDATE system_settings
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    """)

    alter table(:system_settings) do
      modify :brand_id, :bigint, null: false
    end

    drop unique_index(:system_settings, [:key])
    create unique_index(:system_settings, [:brand_id, :key])
    create index(:system_settings, [:brand_id])
  end
end
