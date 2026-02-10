defmodule SocialObjects.Repo.Migrations.AddSampleFulfillmentTracking do
  use Ecto.Migration

  def change do
    alter table(:creator_samples) do
      # Fulfillment tracking
      add :fulfilled, :boolean, default: false
      add :fulfilled_at, :utc_datetime
      # Link to the video that fulfilled this sample (strict product match)
      add :attributed_video_id, references(:creator_videos, on_delete: :nilify_all)
    end

    # Add reference from videos back to the sample they fulfilled
    alter table(:creator_videos) do
      add :attributed_sample_id, references(:creator_samples, on_delete: :nilify_all)
    end

    # Index for finding unfulfilled samples
    create index(:creator_samples, [:fulfilled])
    create index(:creator_samples, [:attributed_video_id])
    create index(:creator_videos, [:attributed_sample_id])
  end
end
