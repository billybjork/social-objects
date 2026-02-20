defmodule SocialObjects.Creators.CreatorVideoMetricSnapshot do
  @moduledoc """
  Daily snapshots of TikTok video metrics for fixed rolling windows (e.g. 30d/90d).

  These rows power period-specific `/videos` metrics without changing the underlying
  video set. Each row stores the best canonical metric row selected during a sync
  run for a specific `{brand_id, tiktok_video_id, snapshot_date, window_days}`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          brand_id: pos_integer() | nil,
          creator_video_id: pos_integer() | nil,
          tiktok_video_id: String.t() | nil,
          snapshot_date: Date.t() | nil,
          window_days: integer() | nil,
          gmv_cents: integer(),
          views: integer(),
          items_sold: integer(),
          gpm_cents: integer() | nil,
          ctr: Decimal.t() | nil,
          source_run_id: String.t() | nil,
          raw_payload: map() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "creator_video_metric_snapshots" do
    belongs_to :brand, SocialObjects.Catalog.Brand

    belongs_to :creator_video, SocialObjects.Creators.CreatorVideo, foreign_key: :creator_video_id

    field :tiktok_video_id, :string
    field :snapshot_date, :date
    field :window_days, :integer

    field :gmv_cents, :integer, default: 0
    field :views, :integer, default: 0
    field :items_sold, :integer, default: 0
    field :gpm_cents, :integer
    field :ctr, :decimal

    field :source_run_id, :string
    field :raw_payload, :map

    timestamps()
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :creator_video_id,
      :tiktok_video_id,
      :snapshot_date,
      :window_days,
      :gmv_cents,
      :views,
      :items_sold,
      :gpm_cents,
      :ctr,
      :source_run_id,
      :raw_payload
    ])
    |> validate_required([:brand_id, :tiktok_video_id, :snapshot_date, :window_days])
    |> validate_inclusion(:window_days, [30, 90])
    |> unique_constraint(
      [:brand_id, :tiktok_video_id, :snapshot_date, :window_days],
      name: :creator_video_metric_snapshots_brand_video_date_window_idx
    )
    |> foreign_key_constraint(:brand_id)
    |> foreign_key_constraint(:creator_video_id)
  end
end
