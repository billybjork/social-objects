defmodule Pavoi.Outreach.OutreachLog do
  @moduledoc """
  Logs outreach communications sent to creators.

  Tracks email and SMS messages sent via SendGrid and Twilio,
  including delivery status and any errors.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @channels ~w(email sms)
  @statuses ~w(sent failed bounced delivered)

  alias Pavoi.Outreach.EmailEvent

  schema "outreach_logs" do
    belongs_to :creator, Pavoi.Creators.Creator
    has_many :email_events, EmailEvent

    # Channel: "email" or "sms"
    field :channel, :string

    # Status: "sent", "failed", "bounced", "delivered"
    field :status, :string

    # Provider message ID (SendGrid message ID or Twilio SID)
    field :provider_id, :string

    # Error details if failed
    field :error_message, :string

    # When the message was sent
    field :sent_at, :utc_datetime

    # Engagement timestamps (set by webhook events)
    field :delivered_at, :utc_datetime
    field :opened_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :bounced_at, :utc_datetime
    field :spam_reported_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(outreach_log, attrs) do
    outreach_log
    |> cast(attrs, [
      :creator_id,
      :channel,
      :status,
      :provider_id,
      :error_message,
      :sent_at,
      :delivered_at,
      :opened_at,
      :clicked_at,
      :bounced_at,
      :spam_reported_at,
      :unsubscribed_at
    ])
    |> validate_required([:creator_id, :channel, :status, :sent_at])
    |> validate_inclusion(:channel, @channels)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Returns the list of valid channels.
  """
  def channels, do: @channels

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Computes the engagement status for display purposes.

  Returns a tuple of {status_label, status_type} where status_type is used for styling:
  - :pending - not yet sent
  - :sent - sent but no delivery confirmation
  - :delivered - delivered to inbox
  - :opened - recipient opened email
  - :clicked - recipient clicked a link
  - :bounced - email bounced (negative)
  - :spam - marked as spam (negative)
  - :unsubscribed - recipient unsubscribed (neutral/negative)
  - :skipped - manually skipped

  Negative outcomes take precedence. For positive outcomes, shows highest engagement.
  """
  def engagement_status(nil), do: {"Pending", :pending}

  def engagement_status(%__MODULE__{} = log) do
    cond do
      # Negative outcomes take precedence
      log.bounced_at -> {"Bounced", :bounced}
      log.spam_reported_at -> {"Spam", :spam}
      log.unsubscribed_at -> {"Unsubscribed", :unsubscribed}
      # Positive outcomes - show highest engagement
      log.clicked_at -> {"Clicked", :clicked}
      log.opened_at -> {"Opened", :opened}
      log.delivered_at -> {"Delivered", :delivered}
      # Sent but no events yet
      log.status == "sent" -> {"Sent", :sent}
      log.status == "delivered" -> {"Delivered", :delivered}
      log.status == "bounced" -> {"Bounced", :bounced}
      log.status == "failed" -> {"Failed", :bounced}
      true -> {"Sent", :sent}
    end
  end
end
