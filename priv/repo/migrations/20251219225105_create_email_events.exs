defmodule Pavoi.Repo.Migrations.CreateEmailEvents do
  use Ecto.Migration

  def change do
    create table(:email_events) do
      add :outreach_log_id, references(:outreach_logs, on_delete: :delete_all)
      add :event_type, :string, null: false
      add :email, :string
      add :timestamp, :utc_datetime, null: false
      add :url, :string
      add :reason, :string
      add :sg_message_id, :string
      add :raw_payload, :map

      timestamps()
    end

    create index(:email_events, [:outreach_log_id])
    create index(:email_events, [:event_type])
    create index(:email_events, [:sg_message_id])
    create index(:email_events, [:timestamp])
  end
end
