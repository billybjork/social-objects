defmodule SocialObjects.Repo.Migrations.AddPrimaryDomainToBrands do
  use Ecto.Migration

  def up do
    alter table(:brands) do
      add :primary_domain, :string
    end

    create unique_index(:brands, [:primary_domain], where: "primary_domain IS NOT NULL")

    execute """
    INSERT INTO brands (name, slug, inserted_at, updated_at)
    SELECT 'PAVOI', 'pavoi', NOW(), NOW()
    WHERE NOT EXISTS (SELECT 1 FROM brands WHERE slug = 'pavoi');
    """

    execute """
    UPDATE brands
    SET primary_domain = 'app.pavoi.com'
    WHERE slug = 'pavoi' AND primary_domain IS NULL;
    """
  end

  def down do
    drop_if_exists index(:brands, [:primary_domain])

    alter table(:brands) do
      remove :primary_domain
    end
  end
end
