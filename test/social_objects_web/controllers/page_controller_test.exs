defmodule SocialObjectsWeb.PageControllerTest do
  use SocialObjectsWeb.ConnCase

  test "GET / redirects to /users/log-in for unauthenticated users", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
