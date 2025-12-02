defmodule Pavoi.Creators.CreatorPerformanceSnapshot do
  @moduledoc """
  Point-in-time snapshots of creator performance metrics.

  Enables historical tracking of creator performance over time,
  with data sourced from various platforms like Refunnel or TikTok API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @sources ~w(refunnel tiktok_api manual csv_import)

  schema "creator_performance_snapshots" do
    belongs_to :creator, Pavoi.Creators.Creator

    field :snapshot_date, :date
    field :source, :string

    # Metrics
    field :follower_count, :integer
    field :gmv_cents, :integer
    field :emv_cents, :integer
    field :total_posts, :integer
    field :total_likes, :integer
    field :total_comments, :integer
    field :total_shares, :integer
    field :total_impressions, :integer
    field :engagement_count, :integer

    timestamps()
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :creator_id,
      :snapshot_date,
      :source,
      :follower_count,
      :gmv_cents,
      :emv_cents,
      :total_posts,
      :total_likes,
      :total_comments,
      :total_shares,
      :total_impressions,
      :engagement_count
    ])
    |> validate_required([:creator_id, :snapshot_date])
    |> validate_inclusion(:source, @sources)
    |> unique_constraint([:creator_id, :snapshot_date, :source])
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Returns the list of valid sources.
  """
  def sources, do: @sources
end
