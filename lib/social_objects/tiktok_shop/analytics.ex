defmodule SocialObjects.TiktokShop.Analytics do
  @moduledoc """
  TikTok Shop Analytics API integration.

  Provides access to shop performance, LIVE stream analytics, video performance,
  and product/SKU performance data from TikTok Shop's Analytics API.

  Required scope: data.shop_analytics.public.read
  """

  alias SocialObjects.TiktokShop
  alias SocialObjects.TiktokShop.Parsers

  # =============================================================================
  # Shop Performance
  # =============================================================================

  @doc """
  Returns performance metrics at shop/seller level.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD format), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD format), required
    - granularity: "ALL" (aggregate) or "1D" (daily), default: "ALL"
    - currency: "USD" or "LOCAL", default: "LOCAL"

  ## Example
      get_shop_performance(brand_id, start_date_ge: "2026-02-01", end_date_lt: "2026-02-09")
  """
  def get_shop_performance(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(brand_id, :get, "/analytics/202509/shop/performance", params)
  end

  @doc """
  Returns daily performance broken down by hour, within 30 days.
  Including today.

  ## Options
    - date: Date in YYYY-MM-DD format, required
    - currency: "USD" or "LOCAL", default: "LOCAL"

  ## Example
      get_shop_performance_per_hour(brand_id, date: "2026-02-08")
  """
  def get_shop_performance_per_hour(brand_id, opts \\ []) do
    date = Keyword.fetch!(opts, :date)
    params = %{}
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202510/shop/performance/#{date}/performance_per_hour",
      params
    )
  end

  # =============================================================================
  # LIVE Performance
  # =============================================================================

  @doc """
  Returns a list of LIVE stream sessions and associated metrics for a shop.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - page_size: Number per page (max 100, default 10)
    - page_token: Pagination token
    - sort_field: gmv, products_added, different_products_sold, sku_orders,
                  items_sold, customers, 24h_live_gmv (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"
    - account_type: ALL, OFFICIAL_ACCOUNTS, MARKETING_ACCOUNTS, AFFILIATE_ACCOUNTS

  ## Example
      get_shop_live_performance_list(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_live_performance_list(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :page_size, Keyword.get(opts, :page_size))
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))
    params = maybe_add_param(params, :account_type, Keyword.get(opts, :account_type))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_lives/performance",
      params
    )
  end

  @doc """
  Returns overall performance metrics for all LIVE stream sessions under a shop.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - today: If true, returns real-time metrics of today (overrides date params)
    - granularity: "ALL" or "1D"
    - currency: "USD" or "LOCAL"
    - account_type: ALL, OFFICIAL_ACCOUNTS, MARKETING_ACCOUNTS, AFFILIATE_ACCOUNTS

  ## Example
      get_shop_live_performance_overview(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_live_performance_overview(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :today, Keyword.get(opts, :today))
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))
    params = maybe_add_param(params, :account_type, Keyword.get(opts, :account_type))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_lives/overview_performance",
      params
    )
  end

  @doc """
  Returns minute-by-minute performance breakdown for a finished LIVE session.

  Note: Only returns data for live streams hosted by shop official account or marketing account.

  ## Known Issue (as of Feb 2026)

  This endpoint consistently returns HTTP 500 (code 98001001 "internal error") for all
  live sessions. The session-level API (`get_shop_live_performance_list`) works correctly.

  ## Options
    - live_id: TikTok Shop LIVE session ID, required
    - page_token: Pagination token
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_live_performance_per_minutes(brand_id, live_id: "7123456789")
  """
  def get_shop_live_performance_per_minutes(brand_id, opts \\ []) do
    live_id = Keyword.fetch!(opts, :live_id)
    params = %{}
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202510/shop_lives/#{live_id}/performance_per_minutes",
      params
    )
  end

  @doc """
  Returns sale performance of each product during a LIVE session.

  Works for official account & marketing accounts.

  ## Options
    - live_id: TikTok Shop LIVE session ID, required
    - sort_field: direct_gmv, items_sold, customers, created_sku_orders,
                  sku_orders, main_orders, product_impressions, produt_clicks (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_live_products_performance(brand_id, live_id: "7123456789")
  """
  def get_shop_live_products_performance(brand_id, opts \\ []) do
    live_id = Keyword.fetch!(opts, :live_id)
    params = %{}
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202512/shop/#{live_id}/products_performance",
      params
    )
  end

  # =============================================================================
  # Video Performance
  # =============================================================================

  @doc """
  Returns a list of videos and associated metrics for a shop.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - page_size: Number per page (max 100, default 10)
    - page_token: Pagination token
    - sort_field: gmv, gpm, avg_customers, sku_orders, items_sold, views,
                  click_through_rate (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"
    - account_type: ALL, OFFICIAL_ACCOUNTS, MARKETING_ACCOUNTS, AFFILIATE_ACCOUNTS

  ## Example
      get_shop_video_performance_list(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_video_performance_list(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :page_size, Keyword.get(opts, :page_size))
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))
    params = maybe_add_param(params, :account_type, Keyword.get(opts, :account_type))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_videos/performance",
      params
    )
  end

  @doc """
  Returns overall performance metrics for all videos under a shop.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - today: If true, returns real-time metrics of today
    - granularity: "ALL" or "1D"
    - currency: "USD" or "LOCAL"
    - account_type: ALL, OFFICIAL_ACCOUNTS, MARKETING_ACCOUNTS, AFFILIATE_ACCOUNTS

  ## Example
      get_shop_video_performance_overview(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_video_performance_overview(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :today, Keyword.get(opts, :today))
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))
    params = maybe_add_param(params, :account_type, Keyword.get(opts, :account_type))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_videos/overview_performance",
      params
    )
  end

  @doc """
  Returns detailed performance metrics for a specific video.

  ## Options
    - video_id: TikTok video ID, required
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - granularity: "ALL" or "1D"
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_video_performance_details(brand_id, video_id: "7123456789",
        start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_video_performance_details(brand_id, opts \\ []) do
    video_id = Keyword.fetch!(opts, :video_id)
    params = build_date_params(opts)
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_videos/#{video_id}/performance",
      params
    )
  end

  @doc """
  Returns performance metrics for products promoted in a given video.

  ## Options
    - video_id: TikTok video ID, required
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - page_size: Number per page (max 100, default 10)
    - page_token: Pagination token
    - sort_field: gmv, units_sold, daily_avg_buyers (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_video_products_performance(brand_id, video_id: "7123456789",
        start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_video_products_performance(brand_id, opts \\ []) do
    video_id = Keyword.fetch!(opts, :video_id)
    params = build_date_params(opts)
    params = maybe_add_param(params, :page_size, Keyword.get(opts, :page_size))
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_videos/#{video_id}/products/performance",
      params
    )
  end

  # =============================================================================
  # Product Performance
  # =============================================================================

  @doc """
  Returns a list of product performance overview metrics.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - page_size: Number per page (max 100, default 10)
    - page_token: Pagination token
    - sort_field: gmv, items_sold, orders (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"
    - category_filter: List of category IDs
    - product_status_filter: "LIVE", "INACTIVE", or "ALL" (default: ALL)

  ## Example
      get_shop_product_performance_list(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_product_performance_list(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :page_size, Keyword.get(opts, :page_size))
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    params =
      maybe_add_param(params, :product_status_filter, Keyword.get(opts, :product_status_filter))

    # Note: category_filter requires special handling for array params
    params = maybe_add_array_param(params, :category_filter, Keyword.get(opts, :category_filter))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_products/performance",
      params
    )
  end

  @doc """
  Returns detailed performance metrics for a specific product.

  ## Options
    - product_id: TikTok Shop product ID, required
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - granularity: "ALL" or "1D"
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_product_performance_detail(brand_id, product_id: "1234567890",
        start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_product_performance_detail(brand_id, opts \\ []) do
    product_id = Keyword.fetch!(opts, :product_id)
    params = build_date_params(opts)
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_products/#{product_id}/performance",
      params
    )
  end

  # =============================================================================
  # SKU Performance
  # =============================================================================

  @doc """
  Returns a list of SKU performance metrics.

  ## Options
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - page_size: Number per page (max 100)
    - page_token: Pagination token
    - sort_field: gmv, sku_orders, units_sold (default: gmv)
    - sort_order: "ASC" or "DESC" (default: DESC)
    - currency: "USD" or "LOCAL"
    - category_filter: List of category IDs
    - product_status_filter: "LIVE", "INACTIVE", or "ALL" (default: ALL)
    - product_ids: List of product IDs to filter SKUs

  ## Example
      get_shop_sku_performance_list(brand_id, start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_sku_performance_list(brand_id, opts \\ []) do
    params = build_date_params(opts)
    params = maybe_add_param(params, :page_size, Keyword.get(opts, :page_size))
    params = maybe_add_param(params, :page_token, Keyword.get(opts, :page_token))
    params = maybe_add_param(params, :sort_field, Keyword.get(opts, :sort_field))
    params = maybe_add_param(params, :sort_order, Keyword.get(opts, :sort_order))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    params =
      maybe_add_param(params, :product_status_filter, Keyword.get(opts, :product_status_filter))

    params = maybe_add_array_param(params, :category_filter, Keyword.get(opts, :category_filter))
    params = maybe_add_array_param(params, :product_ids, Keyword.get(opts, :product_ids))

    TiktokShop.make_api_request(brand_id, :get, "/analytics/202509/shop_skus/performance", params)
  end

  @doc """
  Returns performance metrics for a specific SKU.

  ## Options
    - sku_id: TikTok Shop SKU ID, required
    - start_date_ge: Start date (ISO 8601 YYYY-MM-DD), required
    - end_date_lt: End date (ISO 8601 YYYY-MM-DD), required
    - granularity: "ALL" or "1D"
    - currency: "USD" or "LOCAL"

  ## Example
      get_shop_sku_performance(brand_id, sku_id: "1234567890",
        start_date_ge: "2026-01-01", end_date_lt: "2026-02-09")
  """
  def get_shop_sku_performance(brand_id, opts \\ []) do
    sku_id = Keyword.fetch!(opts, :sku_id)
    params = build_date_params(opts)
    params = maybe_add_param(params, :granularity, Keyword.get(opts, :granularity))
    params = maybe_add_param(params, :currency, Keyword.get(opts, :currency, "USD"))

    TiktokShop.make_api_request(
      brand_id,
      :get,
      "/analytics/202509/shop_skus/#{sku_id}/performance",
      params
    )
  end

  # =============================================================================
  # Stream Helpers
  # =============================================================================

  @time_tolerance_seconds 5 * 60

  @doc """
  Attempts to fetch product performance data for a stream.

  This is used at report time to try getting product sales data immediately
  after a stream ends. The function will:
  1. Fetch live sessions from the API for the stream's date
  2. Match by username and time overlap
  3. If found, fetch and return product performance

  Returns `{:ok, product_performance}` or `{:error, reason}`.
  The product_performance map has a "products" key with a list of products.

  ## Example

      try_fetch_product_performance_for_stream(brand_id, stream)
      # => {:ok, %{"products" => [%{"product_name" => "...", "gmv_cents" => 1500, ...}]}}
      # => {:error, :no_match}
      # => {:error, :api_error}
  """
  def try_fetch_product_performance_for_stream(brand_id, stream) do
    # Calculate date range for the stream
    start_date =
      stream.started_at
      |> DateTime.add(-1, :day)
      |> DateTime.to_date()
      |> Date.to_iso8601()

    end_date =
      (stream.ended_at || stream.started_at)
      |> DateTime.add(2, :day)
      |> DateTime.to_date()
      |> Date.to_iso8601()

    # Fetch live sessions for this date range
    case get_shop_live_performance_list(brand_id,
           start_date_ge: start_date,
           end_date_lt: end_date,
           page_size: 50,
           account_type: "ALL"
         ) do
      {:ok, %{"data" => data}} when is_map(data) ->
        sessions = Map.get(data, "live_stream_sessions", [])
        find_and_fetch_product_performance(brand_id, stream, sessions)

      {:ok, %{"data" => nil}} ->
        {:error, :no_match}

      {:ok, %{"data" => data}} ->
        {:error, {:unexpected_data_payload, data}}

      {:ok, %{"code" => code}} ->
        {:error, {:api_error, code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_and_fetch_product_performance(brand_id, stream, sessions) do
    matching_session =
      Enum.find(sessions, fn session ->
        username_matches?(stream, session) && time_overlaps?(stream, session)
      end)

    case matching_session do
      nil ->
        {:error, :no_match}

      session ->
        live_id = session["id"]
        fetch_parsed_product_performance(brand_id, live_id)
    end
  end

  defp fetch_parsed_product_performance(brand_id, live_id) do
    case get_shop_live_products_performance(brand_id,
           live_id: live_id,
           currency: "USD"
         ) do
      {:ok, %{"data" => data}} when is_map(data) ->
        products = Map.get(data, "products", [])
        parsed = Parsers.parse_product_performance(products)
        {:ok, %{"products" => parsed}}

      {:ok, %{"data" => nil}} ->
        {:ok, %{"products" => []}}

      {:ok, %{"data" => data}} ->
        {:error, {:unexpected_data_payload, data}}

      {:ok, %{"code" => code}} ->
        {:error, {:api_error, code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp username_matches?(stream, session) do
    stream_username = String.downcase(stream.unique_id || "")
    api_username = String.downcase(session["username"] || "")
    stream_username == api_username
  end

  defp time_overlaps?(stream, session) do
    now = DateTime.utc_now()
    api_start = Parsers.parse_unix_timestamp(session["start_time"]) || now
    api_end = Parsers.parse_unix_timestamp(session["end_time"]) || now

    stream_start =
      (stream.started_at || now)
      |> DateTime.add(-@time_tolerance_seconds, :second)

    stream_end =
      (stream.ended_at || now)
      |> DateTime.add(@time_tolerance_seconds, :second)

    DateTime.compare(stream_start, api_end) in [:lt, :eq] &&
      DateTime.compare(stream_end, api_start) in [:gt, :eq]
  end

  # =============================================================================
  # Stream Analytics Sync Helpers
  # =============================================================================

  @doc """
  Builds analytics attributes from API session data for updating a stream.

  Used by both the regular sync worker and the backfill task to ensure
  consistent field mapping.
  """
  def build_stream_analytics_attrs(session, synced_at, opts \\ []) do
    interaction = session["interaction_performance"] || %{}
    sales = session["sales_performance"] || %{}

    per_minute_data = Keyword.get(opts, :per_minute_data)
    product_performance = Keyword.get(opts, :product_performance)

    %{
      tiktok_live_id: session["id"],
      official_gmv_cents: Parsers.parse_gmv_cents(sales["gmv"]),
      gmv_24h_cents: Parsers.parse_gmv_cents(sales["24h_live_gmv"]),
      avg_view_duration_seconds: Parsers.parse_integer(interaction["avg_viewing_duration"]),
      product_impressions: Parsers.parse_integer(interaction["product_impressions"]),
      product_clicks: Parsers.parse_integer(interaction["product_clicks"]),
      unique_customers: Parsers.parse_integer(sales["customers"]),
      conversion_rate: Parsers.parse_percentage(sales["click_to_order_rate"]),
      total_views: Parsers.parse_integer(interaction["views"]),
      items_sold: Parsers.parse_integer(sales["items_sold"]),
      click_through_rate: Parsers.parse_percentage(interaction["click_through_rate"]),

      # New official_ fields
      official_likes: Parsers.parse_integer(interaction["likes"]),
      official_comments: Parsers.parse_integer(interaction["comments"]),
      official_shares: Parsers.parse_integer(interaction["shares"]),
      official_new_followers: Parsers.parse_integer(interaction["new_followers"]),
      official_unique_viewers: Parsers.parse_integer(interaction["viewers"]),
      official_avg_price_cents: Parsers.parse_gmv_cents(sales["avg_price"]),
      official_created_sku_orders: Parsers.parse_integer(sales["created_sku_orders"]),
      official_products_sold_count: Parsers.parse_integer(sales["different_products_sold"]),
      official_products_added: Parsers.parse_integer(sales["products_added"]),
      analytics_synced_at: synced_at,
      analytics_per_minute: per_minute_data,
      product_performance: product_performance
    }
  end

  @doc """
  Finds matching session for a stream from a list of API sessions.

  Matching priority:
  1. Direct ID match (session["id"] == stream.tiktok_live_id)
  2. Username + time overlap match (takes highest GMV if multiple)

  Returns `{:ok, session}` or `:no_match`.
  """
  def find_matching_session(stream, sessions) do
    # Try direct ID match first
    sessions
    |> Enum.find(&(&1["id"] == stream.tiktok_live_id))
    |> case do
      nil -> find_session_by_username_and_time(stream, sessions)
      session -> {:ok, session}
    end
  end

  @doc """
  Fetches all live sessions with full pagination.

  Options:
    - :account_type - "ALL", "AFFILIATE_ACCOUNTS", etc. (default: "ALL")
    - :rate_limit_delay - ms to sleep between pages (default: 0, set 300 for backfill)
  """
  def fetch_all_live_sessions(brand_id, start_date, end_date, opts \\ []) do
    account_type = Keyword.get(opts, :account_type, "ALL")
    rate_limit_delay = Keyword.get(opts, :rate_limit_delay, 0)

    fetch_all_session_pages(
      brand_id,
      start_date,
      end_date,
      account_type,
      rate_limit_delay,
      nil,
      []
    )
  end

  defp fetch_all_session_pages(
         brand_id,
         start_date,
         end_date,
         account_type,
         rate_limit_delay,
         page_token,
         acc
       ) do
    opts = [
      start_date_ge: start_date,
      end_date_lt: end_date,
      page_size: 100,
      sort_field: "gmv",
      sort_order: "DESC",
      account_type: account_type
    ]

    opts = if page_token, do: Keyword.put(opts, :page_token, page_token), else: opts

    response = get_shop_live_performance_list(brand_id, opts)

    handle_fetch_sessions_response(
      response,
      brand_id,
      start_date,
      end_date,
      account_type,
      rate_limit_delay,
      acc
    )
  end

  defp handle_fetch_sessions_response(
         {:ok, %{"data" => data}},
         brand_id,
         start_date,
         end_date,
         account_type,
         rate_limit_delay,
         acc
       )
       when is_map(data) do
    sessions = Map.get(data, "live_stream_sessions", [])
    next_token = Map.get(data, "next_page_token")
    all_sessions = acc ++ sessions

    maybe_continue_session_pagination(
      next_token,
      brand_id,
      start_date,
      end_date,
      account_type,
      rate_limit_delay,
      all_sessions
    )
  end

  defp handle_fetch_sessions_response(
         {:ok, %{"data" => nil}},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         acc
       ),
       do: {:ok, acc}

  defp handle_fetch_sessions_response(
         {:ok, %{"data" => _data}},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         _acc
       ),
       do: {:error, :unexpected_data}

  defp handle_fetch_sessions_response(
         {:ok, %{"code" => 429}},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         _acc
       ),
       do: {:error, :rate_limited}

  defp handle_fetch_sessions_response(
         {:ok, %{"code" => code}},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         _acc
       )
       when code >= 500,
       do: {:error, {:server_error, code}}

  defp handle_fetch_sessions_response(
         {:error, {:rate_limited, _body}},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         _acc
       ),
       do: {:error, :rate_limited}

  defp handle_fetch_sessions_response(
         {:error, reason},
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         _acc
       ),
       do: {:error, reason}

  defp maybe_continue_session_pagination(
         next_token,
         brand_id,
         start_date,
         end_date,
         account_type,
         rate_limit_delay,
         all_sessions
       )
       when is_binary(next_token) and next_token != "" do
    if rate_limit_delay > 0, do: Process.sleep(rate_limit_delay)

    fetch_all_session_pages(
      brand_id,
      start_date,
      end_date,
      account_type,
      rate_limit_delay,
      next_token,
      all_sessions
    )
  end

  defp maybe_continue_session_pagination(
         _next_token,
         _brand_id,
         _start_date,
         _end_date,
         _account_type,
         _rate_limit_delay,
         all_sessions
       ),
       do: {:ok, all_sessions}

  defp find_session_by_username_and_time(stream, sessions) do
    sessions
    |> Enum.filter(fn session ->
      username_matches?(stream, session) && time_overlaps?(stream, session)
    end)
    |> pick_best_matching_session()
  end

  defp pick_best_matching_session([]), do: :no_match
  defp pick_best_matching_session([session]), do: {:ok, session}

  defp pick_best_matching_session(multiple) do
    best =
      Enum.max_by(multiple, fn s ->
        Parsers.parse_gmv_amount(get_in(s, ["sales_performance", "gmv"]))
      end)

    {:ok, best}
  end

  # =============================================================================
  # Private Helpers
  # =============================================================================

  defp build_date_params(opts) do
    %{
      start_date_ge: Keyword.get(opts, :start_date_ge),
      end_date_lt: Keyword.get(opts, :end_date_lt)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)

  defp maybe_add_array_param(params, _key, nil), do: params
  defp maybe_add_array_param(params, _key, []), do: params

  defp maybe_add_array_param(params, key, values) when is_list(values) do
    # TikTok API expects array params as comma-separated values
    Map.put(params, key, Enum.join(values, ","))
  end
end
