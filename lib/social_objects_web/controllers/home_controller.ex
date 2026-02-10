defmodule SocialObjectsWeb.HomeController do
  use SocialObjectsWeb, :controller

  alias SocialObjects.Accounts
  alias SocialObjects.Accounts.Scope
  alias SocialObjects.Catalog.Brand
  alias SocialObjectsWeb.BrandRoutes

  def index(conn, _params) do
    case conn.assigns.current_scope do
      %Scope{user: user} ->
        case Accounts.get_default_brand_for_user(user) do
          %Brand{} = brand ->
            redirect_to_brand(conn, brand)

          nil ->
            conn
            |> put_flash(:error, "You don't have access to any brands yet.")
            |> redirect(to: ~p"/users/log-in")
        end

      _ ->
        redirect(conn, to: ~p"/users/log-in")
    end
  end

  defp redirect_to_brand(conn, brand) do
    path = BrandRoutes.brand_home_path(brand, conn.host)

    if String.starts_with?(path, "http") do
      redirect(conn, external: path)
    else
      redirect(conn, to: path)
    end
  end
end
