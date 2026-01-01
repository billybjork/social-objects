defmodule PavoiWeb.Redirector do
  @moduledoc """
  Simple controller for redirecting routes.
  """
  use PavoiWeb, :controller

  def redirect_to_readme(conn, _params) do
    redirect(conn, to: ~p"/readme")
  end
end
