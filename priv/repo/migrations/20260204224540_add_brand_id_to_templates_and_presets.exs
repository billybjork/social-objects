defmodule Pavoi.Repo.Migrations.AddBrandIdToTemplatesAndPresets do
  use Ecto.Migration

  def up do
    alter table(:email_templates) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    alter table(:message_presets) do
      add :brand_id, references(:brands, on_delete: :delete_all), null: true
    end

    execute """
    UPDATE email_templates
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    execute """
    UPDATE message_presets
    SET brand_id = (SELECT id FROM brands WHERE slug = 'pavoi' LIMIT 1)
    WHERE brand_id IS NULL;
    """

    alter table(:email_templates) do
      modify :brand_id, :bigint, null: false
    end

    alter table(:message_presets) do
      modify :brand_id, :bigint, null: false
    end

    drop_if_exists index(:email_templates, [:name])
    create unique_index(:email_templates, [:brand_id, :name])

    create index(:email_templates, [:brand_id])
    create index(:message_presets, [:brand_id])
  end

  def down do
    drop_if_exists index(:email_templates, [:brand_id, :name])
    drop_if_exists index(:email_templates, [:brand_id])
    drop_if_exists index(:message_presets, [:brand_id])

    create unique_index(:email_templates, [:name])

    alter table(:email_templates) do
      remove :brand_id
    end

    alter table(:message_presets) do
      remove :brand_id
    end
  end
end
