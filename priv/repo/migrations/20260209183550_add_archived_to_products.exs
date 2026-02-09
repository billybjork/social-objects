defmodule Pavoi.Repo.Migrations.AddArchivedToProducts do
  use Ecto.Migration

  @moduledoc """
  Adds soft archive support to products.

  Products can be archived when they no longer match Shopify sync filters
  (e.g., tag-based filtering for multi-brand stores). Archived products:
  - Are excluded from product lists/search by default
  - Remain visible in product sets (with visual indicator)
  - Can be auto-unarchived when they match filters again
  """

  def change do
    alter table(:products) do
      add :archived_at, :utc_datetime
      add :archive_reason, :string
    end

    # Index for efficient filtering of non-archived products
    create index(:products, [:brand_id, :archived_at])
  end
end
