defmodule SocialObjects.Outreach.EmailEvent do
  @moduledoc """
  Tracks email events received from SendGrid webhooks.

  Events include delivery status (delivered, bounce, dropped, deferred)
  and engagement events (open, click, spamreport, unsubscribe).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @event_types ~w(delivered bounce dropped deferred processed open click spamreport unsubscribe group_unsubscribe group_resubscribe)

  schema "email_events" do
    belongs_to :outreach_log, SocialObjects.Outreach.OutreachLog

    field :event_type, :string
    field :email, :string
    field :timestamp, :utc_datetime
    field :url, :string
    field :reason, :string
    field :sg_message_id, :string
    field :raw_payload, :map

    timestamps()
  end

  @doc false
  def changeset(email_event, attrs) do
    email_event
    |> cast(attrs, [
      :outreach_log_id,
      :event_type,
      :email,
      :timestamp,
      :url,
      :reason,
      :sg_message_id,
      :raw_payload
    ])
    |> validate_required([:event_type, :timestamp])
    |> validate_inclusion(:event_type, @event_types)
    |> foreign_key_constraint(:outreach_log_id)
  end

  @doc """
  Returns the list of valid event types.
  """
  def event_types, do: @event_types
end
