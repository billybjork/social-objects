defmodule SocialObjectsWeb.UserInviteController do
  use SocialObjectsWeb, :controller

  alias SocialObjects.Accounts
  alias SocialObjects.Settings
  alias SocialObjectsWeb.BrandRoutes
  alias SocialObjectsWeb.UserAuth

  def accept(conn, %{"token" => token}) do
    case Accounts.accept_brand_invite(token) do
      {:ok, user, brand} ->
        welcome = "Welcome to #{brand.name || Settings.app_name()}!"
        return_to = BrandRoutes.brand_home_path_for_host(brand, conn.host)

        conn
        |> put_flash(:info, welcome)
        |> put_session(:user_return_to, return_to)
        |> UserAuth.log_in_user(user)

      {:error, :expired} ->
        redirect_with_error(conn, "This invite link has expired.")

      {:error, :accepted} ->
        redirect_with_error(conn, "This invite link has already been used.")

      {:error, :not_found} ->
        redirect_with_error(conn, "This invite link is invalid.")

      {:error, :invalid} ->
        redirect_with_error(conn, "This invite link is invalid.")

      {:error, _reason} ->
        redirect_with_error(
          conn,
          "Something went wrong. Please try again or request a new invite."
        )
    end
  end

  defp redirect_with_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/users/log-in")
  end
end
