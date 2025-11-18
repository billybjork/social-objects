defmodule PavoiWeb.AuthController do
  @moduledoc """
  Simple password authentication for the entire site.
  """
  use PavoiWeb, :controller

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def authenticate(conn, %{"password" => password}) do
    site_password = System.get_env("SITE_PASSWORD")

    if site_password && password == site_password do
      return_to = get_session(conn, :return_to) || "/"

      conn
      |> put_session(:authenticated, true)
      |> delete_session(:return_to)
      |> put_flash(:info, "Authentication successful")
      |> redirect(to: return_to)
    else
      conn
      |> put_flash(:error, "Invalid password")
      |> render(:login, error: "Invalid password")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/auth/login")
  end
end
