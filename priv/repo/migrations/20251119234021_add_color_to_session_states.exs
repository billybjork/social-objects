defmodule Pavoi.Repo.Migrations.AddColorToSessionStates do
  use Ecto.Migration

  def change do
    alter table(:session_states) do
      add :current_host_message_color, :string
    end
  end
end
