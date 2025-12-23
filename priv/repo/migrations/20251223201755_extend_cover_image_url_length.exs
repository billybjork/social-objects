defmodule Pavoi.Repo.Migrations.ExtendCoverImageUrlLength do
  use Ecto.Migration

  def change do
    alter table(:tiktok_streams) do
      modify :cover_image_url, :text, from: :string
    end
  end
end
