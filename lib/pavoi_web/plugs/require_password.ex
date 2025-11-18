defmodule PavoiWeb.Plugs.RequirePassword do
  @moduledoc """
  A plug that requires a simple password for accessing the application in production.

  The password is set via the `SITE_PASSWORD` environment variable.
  Once authenticated, a session token is stored so users don't need to re-enter.

  To enable, add to your router:

      pipeline :protected do
        plug PavoiWeb.Plugs.RequirePassword
      end
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip authentication check if SITE_PASSWORD is not set
    case System.get_env("SITE_PASSWORD") do
      nil ->
        conn

      "" ->
        conn

      _password ->
        if authenticated?(conn) do
          conn
        else
          conn
          |> put_session(:return_to, conn.request_path)
          |> redirect(to: "/auth/login")
          |> halt()
        end
    end
  end

  defp authenticated?(conn) do
    get_session(conn, :authenticated) == true
  end
end
