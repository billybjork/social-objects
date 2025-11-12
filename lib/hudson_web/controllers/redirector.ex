defmodule HudsonWeb.Redirector do
  @moduledoc """
  Simple controller for redirecting routes.
  """
  use HudsonWeb, :controller

  def redirect_to_sessions(conn, _params) do
    redirect(conn, to: ~p"/sessions")
  end
end
