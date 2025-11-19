defmodule Pavoi.Repo.Migrations.CreateMessagePresets do
  use Ecto.Migration

  def change do
    create table(:message_presets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :label, :string, null: false
      add :message_text, :text, null: false
      add :color, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:message_presets, [:position])
  end
end
