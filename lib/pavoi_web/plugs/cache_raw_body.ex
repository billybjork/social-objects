defmodule PavoiWeb.Plugs.CacheRawBody do
  @moduledoc """
  A custom body reader that caches the raw request body.

  Used with Plug.Parsers to preserve the raw body for webhook
  signature verification while still allowing JSON parsing.

  The raw body is stored in conn.assigns[:raw_body].

  ## Usage in Endpoint

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library(),
        body_reader: {PavoiWeb.Plugs.CacheRawBody, :read_body, []}
  """

  @doc """
  Reads the request body and caches it in conn.assigns[:raw_body].

  This function conforms to the Plug body reader spec.
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        # Cache the raw body in conn private storage
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        # For large bodies, accumulate in private storage
        existing = Map.get(conn.private, :raw_body, "")
        conn = Plug.Conn.put_private(conn, :raw_body, existing <> body)
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves the cached raw body from the connection.

  Returns nil if the body was not cached (e.g., if CacheRawBody wasn't configured).
  """
  def get_raw_body(conn) do
    Map.get(conn.private, :raw_body)
  end
end
