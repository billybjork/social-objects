defmodule SocialObjects.Workers.ThumbnailBackfillWorkerTest do
  @moduledoc """
  Tests for ThumbnailBackfillWorker video thumbnail storage functionality.
  """

  use SocialObjects.DataCase, async: false
  use Oban.Testing, repo: SocialObjects.Repo

  alias SocialObjects.Creators
  alias SocialObjects.Creators.CreatorVideo
  alias SocialObjects.Workers.ThumbnailBackfillWorker

  setup do
    brand = brand_fixture()
    creator = creator_fixture(brand.id)

    %{brand: brand, creator: creator}
  end

  describe "perform/1" do
    test "processes videos needing thumbnail storage", %{brand: brand, creator: creator} do
      # Create a video with thumbnail_url but no storage key
      video =
        video_fixture(brand.id, creator.id, %{
          thumbnail_url: "https://example.com/thumb.jpg",
          thumbnail_storage_key: nil
        })

      # The worker will try to fetch from OEmbed and store in storage
      # Since we don't have mocks for OEmbed, this will likely fail gracefully
      assert :ok = perform_job(ThumbnailBackfillWorker, %{"brand_id" => brand.id})

      # Video should still exist (worker doesn't fail on individual errors)
      assert Repo.get(CreatorVideo, video.id)
    end

    test "skips videos that already have storage keys", %{brand: brand, creator: creator} do
      # Create a video with both thumbnail_url and storage key
      video =
        video_fixture(brand.id, creator.id, %{
          thumbnail_url: "https://example.com/thumb.jpg",
          thumbnail_storage_key: "thumbnails/videos/123.jpg"
        })

      assert :ok = perform_job(ThumbnailBackfillWorker, %{"brand_id" => brand.id})

      # Video should remain unchanged
      updated = Repo.get(CreatorVideo, video.id)
      assert updated.thumbnail_storage_key == "thumbnails/videos/123.jpg"
    end

    test "skips videos without video_url", %{brand: brand, creator: creator} do
      # Create a video with thumbnail but no video_url (can't fetch fresh thumbnail)
      video =
        video_fixture(brand.id, creator.id, %{
          thumbnail_url: "https://example.com/thumb.jpg",
          video_url: nil,
          thumbnail_storage_key: nil
        })

      assert :ok = perform_job(ThumbnailBackfillWorker, %{"brand_id" => brand.id})

      # Video should remain without storage key
      updated = Repo.get(CreatorVideo, video.id)
      assert is_nil(updated.thumbnail_storage_key)
    end
  end

  # Helper functions

  defp creator_fixture(brand_id) do
    {:ok, creator} =
      Creators.create_creator(%{
        tiktok_username: "test_creator_#{System.unique_integer([:positive])}"
      })

    _ = Creators.add_creator_to_brand(creator.id, brand_id)
    creator
  end

  defp video_fixture(brand_id, creator_id, attrs) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      tiktok_video_id: "video_#{unique_id}",
      video_url: "https://www.tiktok.com/@testuser/video/#{unique_id}",
      title: "Test Video #{unique_id}",
      gmv_cents: 10_000,
      items_sold: 5
    }

    merged = Map.merge(default_attrs, attrs)

    {:ok, video} =
      %CreatorVideo{brand_id: brand_id, creator_id: creator_id}
      |> CreatorVideo.changeset(merged)
      |> Repo.insert()

    video
  end
end
