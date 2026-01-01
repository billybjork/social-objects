defmodule PavoiWeb.PageControllerTest do
  use PavoiWeb.ConnCase

  test "GET / redirects to /readme", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/readme"
  end
end
