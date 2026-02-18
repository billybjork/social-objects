defmodule SocialObjectsWeb.VideoComponentsTest do
  @moduledoc """
  Tests for VideoComponents, specifically the video_thumbnail component
  and its handling of storage keys.
  """

  use SocialObjects.DataCase, async: true

  import Phoenix.LiveViewTest

  alias SocialObjectsWeb.VideoComponents

  describe "video_thumbnail/1" do
    test "falls back to thumbnail_url when storage key exists but storage not configured" do
      # In test env, Storage.configured?() returns false, so public_url returns nil
      # and the component falls back to thumbnail_url
      video = %{
        thumbnail_storage_key: "thumbnails/videos/1.jpg",
        thumbnail_url: "https://tiktok.com/fallback-url.jpg"
      }

      html =
        render_component(&VideoComponents.video_thumbnail/1, video: video)

      # Should render img with the fallback thumbnail_url
      assert html =~ "<img"
      assert html =~ "https://tiktok.com/fallback-url.jpg"
      refute html =~ "video-thumbnail__placeholder"
    end

    test "falls back to thumbnail_url when no storage key" do
      video = %{
        thumbnail_storage_key: nil,
        thumbnail_url: "https://tiktok.com/thumb.jpg"
      }

      html =
        render_component(&VideoComponents.video_thumbnail/1, video: video)

      # Should render img with thumbnail_url
      assert html =~ "<img"
      assert html =~ "https://tiktok.com/thumb.jpg"
    end

    test "falls back to thumbnail_url when storage key is empty string" do
      video = %{
        thumbnail_storage_key: "",
        thumbnail_url: "https://tiktok.com/thumb.jpg"
      }

      html =
        render_component(&VideoComponents.video_thumbnail/1, video: video)

      # Should render img with thumbnail_url
      assert html =~ "<img"
      assert html =~ "https://tiktok.com/thumb.jpg"
    end

    test "renders placeholder when no thumbnail available" do
      video = %{
        thumbnail_storage_key: nil,
        thumbnail_url: nil
      }

      html =
        render_component(&VideoComponents.video_thumbnail/1, video: video)

      # Should render placeholder div
      assert html =~ "video-thumbnail__placeholder"
      refute html =~ "<img"
    end

    test "renders placeholder when both thumbnail fields are empty strings" do
      video = %{
        thumbnail_storage_key: "",
        thumbnail_url: ""
      }

      html =
        render_component(&VideoComponents.video_thumbnail/1, video: video)

      # Should render placeholder div (empty string is falsy for thumbnail_url check)
      assert html =~ "video-thumbnail__placeholder"
    end
  end
end
