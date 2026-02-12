defmodule SocialObjectsWeb.TiktokShopController do
  @moduledoc """
  Handles TikTok Shop OAuth callbacks and API operations.
  """
  use SocialObjectsWeb, :controller

  alias SocialObjects.TiktokShop

  @doc """
  OAuth callback handler.
  Called when TikTok redirects back after user authorization.
  Exchanges the authorization code for access tokens and fetches shop information.
  """
  require Logger

  def callback(conn, %{"code" => auth_code, "state" => state} = _params) do
    Logger.info("[TikTok OAuth] Received callback with code and state")

    with {:ok, %{brand_id: brand_id}} <-
           Phoenix.Token.verify(SocialObjectsWeb.Endpoint, "tiktok_oauth", state,
             max_age: 15 * 60
           ),
         _ <- Logger.info("[TikTok OAuth] State verified for brand_id: #{brand_id}"),
         {:ok, _auth} <- TiktokShop.exchange_code_for_token(brand_id, auth_code),
         _ <- Logger.info("[TikTok OAuth] Token exchange successful"),
         {:ok, auth} <- TiktokShop.get_authorized_shops(brand_id) do
      Logger.info("[TikTok OAuth] Successfully connected to shop: #{auth.shop_name || auth.shop_id}")

      conn
      |> put_flash(
        :info,
        "Successfully connected to TikTok Shop: #{auth.shop_name || auth.shop_id}"
      )
      |> redirect(to: "/")
    else
      {:error, error} ->
        Logger.error("[TikTok OAuth] Connection failed: #{inspect(error)}")

        conn
        |> put_flash(:error, "TikTok Shop connection failed. Please try again.")
        |> redirect(to: "/")
    end
  end

  def callback(conn, params) do
    # If there's an error in the OAuth flow
    Logger.warning("[TikTok OAuth] Callback received. All params: #{inspect(params)}")
    error = Map.get(params, "error", "Unknown error")
    error_description = Map.get(params, "error_description", "")

    conn
    |> put_flash(:error, "TikTok Shop authorization error: #{error} - #{error_description}")
    |> redirect(to: "/")
  end

  @doc """
  Test endpoint to verify TikTok Shop API is working.
  Makes a simple API call to get shop information.
  """
  def test(conn, params) do
    brand_id = Map.get(params, "brand_id")

    case TiktokShop.make_api_request(brand_id, :get, "/authorization/202309/shops", %{}) do
      {:ok, response} ->
        json(conn, %{success: true, data: response})

      {:error, error} ->
        conn
        |> put_status(500)
        |> json(%{success: false, error: inspect(error)})
    end
  end
end
