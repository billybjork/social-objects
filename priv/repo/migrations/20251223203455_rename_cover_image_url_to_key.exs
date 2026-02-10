defmodule SocialObjects.Repo.Migrations.RenameCoverImageUrlToKey do
  use Ecto.Migration

  def up do
    # Rename the column
    rename table(:tiktok_streams), :cover_image_url, to: :cover_image_key

    # Extract storage keys from existing presigned URLs
    # URL format: https://bucket.storage.railway.app/streams/36/cover.jpg?X-Amz-...
    # We want just: streams/36/cover.jpg
    execute """
    UPDATE tiktok_streams
    SET cover_image_key = split_part(
      regexp_replace(cover_image_key, '^https?://[^/]+/', ''),
      '?',
      1
    )
    WHERE cover_image_key IS NOT NULL
    AND cover_image_key LIKE 'http%'
    """
  end

  def down do
    # Note: We can't restore full URLs on rollback since they were presigned
    # Just rename the column back
    rename table(:tiktok_streams), :cover_image_key, to: :cover_image_url
  end
end
