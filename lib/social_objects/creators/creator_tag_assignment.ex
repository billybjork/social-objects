defmodule SocialObjects.Creators.CreatorTagAssignment do
  @moduledoc """
  Join table linking creators to tags.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "creator_tag_assignments" do
    belongs_to :creator, SocialObjects.Creators.Creator, type: :id
    belongs_to :creator_tag, SocialObjects.Creators.CreatorTag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:creator_id, :creator_tag_id])
    |> validate_required([:creator_id, :creator_tag_id])
    |> unique_constraint([:creator_id, :creator_tag_id])
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:creator_tag_id)
  end
end
