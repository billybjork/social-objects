defmodule Pavoi.Catalog.Brand do
  @moduledoc """
  Represents a brand in the system.

  Brands own products and product sets. Each brand has a unique slug for URL routing.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "brands" do
    field :name, :string
    field :slug, :string
    field :notes, :string
    field :primary_domain, :string

    has_many :products, Pavoi.Catalog.Product
    has_many :product_sets, Pavoi.ProductSets.ProductSet
    has_many :user_brands, Pavoi.Accounts.UserBrand
    has_many :users, through: [:user_brands, :user]

    timestamps()
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :slug, :notes, :primary_domain])
    |> validate_required([:name, :slug])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
    |> unique_constraint(:primary_domain)
  end
end
