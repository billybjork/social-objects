defmodule Pavoi.Repo.Migrations.AddEngagementFieldsToOutreachLogs do
  use Ecto.Migration

  def change do
    alter table(:outreach_logs) do
      add :delivered_at, :utc_datetime
      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :bounced_at, :utc_datetime
      add :spam_reported_at, :utc_datetime
      add :unsubscribed_at, :utc_datetime
    end
  end
end
