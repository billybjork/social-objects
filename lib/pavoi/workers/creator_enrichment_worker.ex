defmodule Pavoi.Workers.CreatorEnrichmentWorker do
  @moduledoc """
  Oban worker that enriches creator profiles with data from TikTok Marketplace API.

  ## Enrichment Strategy

  1. Find creators with usernames but missing/stale metrics
  2. Search marketplace API by username to find exact match
  3. Update creator with metrics from API response
  4. Create performance snapshot for historical tracking

  ## Prioritization (Recently Sampled First)

  1. Creators with samples in last 30 days (highest priority)
  2. Creators with no performance data ever
  3. Creators with stale data (>7 days since last enrichment)

  ## Rate Limits

  - Marketplace Search API: reasonable limits
  - Process in batches to avoid overwhelming the API
  """

  use Oban.Worker,
    queue: :enrichment,
    max_attempts: 3,
    unique: [period: :infinity, states: [:available, :scheduled, :executing]]

  require Logger
  import Ecto.Query

  alias Pavoi.Creators
  alias Pavoi.Creators.Creator
  alias Pavoi.Repo
  alias Pavoi.Settings
  alias Pavoi.TiktokShop

  # Number of creators to enrich per run
  # With 10k API requests/day limit and 4 runs/day, 2000/run = 8000/day
  @batch_size 2000
  # Delay between API calls (ms) to avoid rate limiting
  # 300ms is safe and keeps batch runtime ~10 minutes
  @api_delay_ms 300

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Phoenix.PubSub.broadcast(Pavoi.PubSub, "creator:enrichment", {:enrichment_started})

    batch_size = Map.get(args, "batch_size", @batch_size)
    Logger.info("Starting creator enrichment (batch_size: #{batch_size})...")

    {:ok, stats} = enrich_creators(batch_size)

    Settings.update_enrichment_last_sync_at()

    Logger.info("""
    Creator enrichment completed
       - Enriched: #{stats.enriched}
       - Not found: #{stats.not_found}
       - Errors: #{stats.errors}
       - Skipped (no username): #{stats.skipped}
    """)

    Phoenix.PubSub.broadcast(Pavoi.PubSub, "creator:enrichment", {:enrichment_completed, stats})
    :ok
  end

  @doc """
  Manually trigger enrichment for a specific creator by username.
  Returns {:ok, creator} or {:error, reason}.
  """
  def enrich_single(creator) when is_struct(creator, Creator) do
    if creator.tiktok_username && creator.tiktok_username != "" do
      enrich_creator(creator)
    else
      {:error, :no_username}
    end
  end

  defp enrich_creators(batch_size) do
    creators = get_creators_to_enrich(batch_size)
    Logger.info("Found #{length(creators)} creators to enrich")

    initial_stats = %{enriched: 0, not_found: 0, errors: 0, skipped: 0}
    stats = Enum.reduce(creators, initial_stats, &process_creator/2)

    {:ok, stats}
  end

  defp process_creator(creator, acc) do
    if is_nil(creator.tiktok_username) or creator.tiktok_username == "" do
      %{acc | skipped: acc.skipped + 1}
    else
      if acc.enriched > 0, do: Process.sleep(@api_delay_ms)
      update_stats(enrich_creator(creator), acc)
    end
  end

  defp update_stats({:ok, _}, acc), do: %{acc | enriched: acc.enriched + 1}
  defp update_stats({:error, :not_found}, acc), do: %{acc | not_found: acc.not_found + 1}
  defp update_stats({:error, _}, acc), do: %{acc | errors: acc.errors + 1}

  defp get_creators_to_enrich(limit) do
    # Prioritize:
    # 1. Creators with recent samples (last 30 days)
    # 2. Creators with no enrichment data
    # 3. Creators with stale data (>7 days)

    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    # Query creators who need enrichment, prioritized by sample recency
    query =
      from(c in Creator,
        left_join: s in assoc(c, :creator_samples),
        where: not is_nil(c.tiktok_username) and c.tiktok_username != "",
        where:
          is_nil(c.last_enriched_at) or
            c.last_enriched_at < ^seven_days_ago,
        group_by: c.id,
        order_by: [
          # Prioritize creators with recent samples
          desc: fragment("MAX(?) > ?", s.ordered_at, ^thirty_days_ago),
          # Then by whether they've never been enriched
          asc: c.last_enriched_at,
          # Then by total GMV (enrich higher-value creators first)
          desc: c.total_gmv_cents
        ],
        limit: ^limit,
        select: c
      )

    Repo.all(query)
  end

  defp enrich_creator(creator) do
    username = creator.tiktok_username

    case TiktokShop.search_marketplace_creators(keyword: username) do
      {:ok, %{creators: creators}} ->
        # Find exact match by username
        case find_exact_match(creators, username) do
          nil ->
            Logger.debug("No marketplace match for @#{username}")
            {:error, :not_found}

          marketplace_creator ->
            update_creator_from_marketplace(creator, marketplace_creator)
        end

      {:error, reason} ->
        Logger.warning("Marketplace search failed for @#{username}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp find_exact_match(creators, username) do
    normalized_username = String.downcase(username)

    Enum.find(creators, fn c ->
      c_username = c["username"] || ""
      String.downcase(c_username) == normalized_username
    end)
  end

  defp update_creator_from_marketplace(creator, marketplace_data) do
    # Extract metrics from marketplace response
    attrs = %{
      follower_count: marketplace_data["follower_count"],
      tiktok_nickname: marketplace_data["nickname"],
      tiktok_avatar_url: get_in(marketplace_data, ["avatar", "url"]),
      last_enriched_at: DateTime.utc_now(),
      enrichment_source: "marketplace_api"
    }

    # Parse GMV if available
    attrs =
      case marketplace_data["gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :total_gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    # Parse video GMV if available
    attrs =
      case marketplace_data["video_gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :video_gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    # Store avg video views if available
    attrs =
      if avg_views = marketplace_data["avg_ec_video_view_count"] do
        Map.put(attrs, :avg_video_views, avg_views)
      else
        attrs
      end

    case Creators.update_creator(creator, attrs) do
      {:ok, updated_creator} ->
        # Also create a performance snapshot for historical tracking
        create_enrichment_snapshot(updated_creator, marketplace_data)
        Logger.debug("Enriched @#{creator.tiktok_username}: #{attrs[:follower_count]} followers, $#{(attrs[:total_gmv_cents] || 0) / 100} GMV")
        {:ok, updated_creator}

      {:error, changeset} ->
        Logger.warning("Failed to update creator @#{creator.tiktok_username}: #{inspect(changeset.errors)}")
        {:error, :update_failed}
    end
  end

  defp create_enrichment_snapshot(creator, marketplace_data) do
    # Create a performance snapshot for historical tracking
    attrs = %{
      creator_id: creator.id,
      snapshot_date: Date.utc_today(),
      source: "marketplace_api",
      follower_count: marketplace_data["follower_count"]
    }

    # Add GMV if available
    attrs =
      case marketplace_data["gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    case Creators.create_performance_snapshot(attrs) do
      {:ok, _snapshot} -> :ok
      {:error, _} -> :ok  # Snapshot creation failure shouldn't fail enrichment
    end
  end
end
