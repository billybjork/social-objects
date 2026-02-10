defmodule SocialObjectsWeb.NavHooks do
  @moduledoc """
  LiveView lifecycle hooks for navigation state.
  """

  def on_mount(:set_current_page, _params, _session, socket) do
    # Get the view module from the socket's private data
    view_module = socket.private[:phoenix_live_view][:view] || socket.view
    current_page = get_current_page(view_module)

    # Load user_brands once here instead of on every render in layout
    user_brands =
      case socket.assigns[:current_scope] do
        %{user: user} when not is_nil(user) ->
          SocialObjects.Accounts.list_user_brands(user)

        _ ->
          []
      end

    socket =
      socket
      |> Phoenix.Component.assign(:current_page, current_page)
      |> Phoenix.Component.assign(:user_brands, user_brands)

    {:cont, socket}
  end

  # Brand pages
  defp get_current_page(SocialObjectsWeb.ProductsLive.Index), do: :products
  defp get_current_page(SocialObjectsWeb.CreatorsLive.Index), do: :creators
  defp get_current_page(SocialObjectsWeb.VideosLive.Index), do: :videos
  defp get_current_page(SocialObjectsWeb.TiktokLive.Index), do: :streams
  defp get_current_page(SocialObjectsWeb.ShopAnalyticsLive.Index), do: :shop_analytics
  defp get_current_page(SocialObjectsWeb.ReadmeLive.Index), do: :readme

  # Admin pages - return :admin so nav shows but no tab is highlighted
  defp get_current_page(SocialObjectsWeb.AdminLive.Dashboard), do: :admin
  defp get_current_page(SocialObjectsWeb.AdminLive.Brands), do: :admin
  defp get_current_page(SocialObjectsWeb.AdminLive.Users), do: :admin
  defp get_current_page(SocialObjectsWeb.AdminLive.Invites), do: :admin

  # Full-page views return nil so navbar doesn't show
  defp get_current_page(SocialObjectsWeb.ProductHostLive.Index), do: nil
  defp get_current_page(SocialObjectsWeb.ProductControllerLive.Index), do: nil
  defp get_current_page(SocialObjectsWeb.TemplateEditorLive), do: nil
  defp get_current_page(_), do: nil
end
