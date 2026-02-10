defmodule SocialObjects.Shopify.Client do
  @moduledoc """
  Shopify GraphQL API client for fetching product data.

  Handles authentication, pagination, rate limiting, and response parsing.

  ## Authentication

  Uses `SocialObjects.Shopify.Auth` to acquire access tokens via client credentials grant.
  Tokens are cached in-memory and automatically refreshed when they expire (24 hours).

  When a request receives a 401 Unauthorized response, this module automatically:
  1. Clears the cached token
  2. Requests a fresh token from Shopify
  3. Retries the request once with the new token

  This ensures the sync continues working even if tokens expire mid-execution.
  """

  require Logger
  alias SocialObjects.Shopify.Auth

  @doc """
  Fetches products from Shopify GraphQL API with pagination support.

  ## Parameters

    - `cursor` - Optional cursor for pagination (default: nil for first page)

  ## Returns

    - `{:ok, %{products: [...], has_next_page: boolean, end_cursor: string | nil}}` on success
    - `{:error, :rate_limited}` when rate limited
    - `{:error, reason}` on other errors

  ## Examples

      iex> SocialObjects.Shopify.Client.fetch_products(brand_id)
      {:ok, %{products: [...], has_next_page: true, end_cursor: "..."}}

      iex> SocialObjects.Shopify.Client.fetch_products(brand_id, "cursor_string")
      {:ok, %{products: [...], has_next_page: false, end_cursor: nil}}
  """
  def fetch_products(brand_id, cursor \\ nil) do
    query = build_products_query()
    variables = %{cursor: cursor}

    case execute_graphql(brand_id, query, variables) do
      {:ok, response} -> parse_products_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches all products by paginating through the entire catalog.

  Returns all products as a flat list.

  ## Returns

    - `{:ok, [products]}` on success
    - `{:error, reason}` on error
  """
  def fetch_all_products(brand_id) do
    fetch_all_products_recursive(brand_id, nil, [])
  end

  defp fetch_all_products_recursive(brand_id, cursor, accumulated_batches) do
    case fetch_products(brand_id, cursor) do
      {:ok, %{products: products, has_next_page: false}} ->
        # Reverse and flatten accumulated batches for correct order
        all_products = Enum.reverse([products | accumulated_batches]) |> List.flatten()
        {:ok, all_products}

      {:ok, %{products: products, has_next_page: true, end_cursor: next_cursor}} ->
        Logger.info("Fetched #{length(products)} products, continuing with cursor...")
        # Prepend batch (O(1)) instead of append (O(n))
        fetch_all_products_recursive(brand_id, next_cursor, [products | accumulated_batches])

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_graphql(brand_id, query, variables, retry \\ true) do
    url = graphql_url(brand_id)
    body = Jason.encode!(%{query: query, variables: variables})

    case build_headers(brand_id) do
      {:ok, headers} ->
        make_graphql_request(brand_id, url, headers, body, query, variables, retry)

      {:error, reason} ->
        Logger.error("Failed to build headers: #{inspect(reason)}")
        {:error, {:auth_error, reason}}
    end
  end

  defp make_graphql_request(brand_id, url, headers, body, query, variables, retry) do
    case Req.post(url, headers: headers, body: body) do
      {:ok, %{status: 200, body: body}} ->
        parse_graphql_body(body)

      {:ok, %{status: 401}} when retry ->
        handle_401_retry(brand_id, query, variables)

      {:ok, %{status: 401}} ->
        Logger.error("Shopify API returned 401 after token refresh - check app credentials")
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        Logger.warning("Shopify API rate limit hit")
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Shopify API error: status=#{status}, body=#{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_graphql_body(%{"data" => data}), do: {:ok, data}
  defp parse_graphql_body(%{"errors" => errors}), do: {:error, {:graphql_errors, errors}}

  defp handle_401_retry(brand_id, query, variables) do
    Logger.warning("Shopify API returned 401 Unauthorized - refreshing token and retrying")
    Auth.clear_token(brand_id)

    case Auth.refresh_access_token(brand_id) do
      {:ok, _token} ->
        Logger.info("Token refreshed, retrying request...")
        # Retry once with new token (retry=false to prevent infinite loop)
        execute_graphql(brand_id, query, variables, false)

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        {:error, {:auth_error, reason}}
    end
  end

  defp parse_products_response(%{"products" => products_data}) do
    products = products_data["nodes"] || []
    page_info = products_data["pageInfo"] || %{}

    {:ok,
     %{
       products: products,
       has_next_page: page_info["hasNextPage"] || false,
       end_cursor: page_info["endCursor"]
     }}
  end

  defp build_products_query do
    """
    query($cursor: String) {
      products(first: 250, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          title
          handle
          descriptionHtml
          vendor
          tags
          createdAt
          updatedAt
          variants(first: 100) {
            nodes {
              id
              title
              price
              compareAtPrice
              sku
              selectedOptions {
                name
                value
              }
            }
          }
          images(first: 10) {
            nodes {
              id
              url
              altText
              height
              width
            }
          }
        }
      }
    }
    """
  end

  defp build_headers(brand_id) do
    case Auth.get_access_token(brand_id) do
      {:ok, token} ->
        {:ok,
         [
           {"Content-Type", "application/json"},
           {"X-Shopify-Access-Token", token}
         ]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp graphql_url(brand_id) do
    store_name = SocialObjects.Settings.get_shopify_store_name(brand_id)

    if is_nil(store_name) do
      raise "Shopify store name not configured for brand #{inspect(brand_id)}"
    end

    "https://#{store_name}.myshopify.com/admin/api/2024-10/graphql.json"
  end
end
