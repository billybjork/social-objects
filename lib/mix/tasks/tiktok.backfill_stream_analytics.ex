defmodule Mix.Tasks.Tiktok.BackfillStreamAnalytics do
  @moduledoc """
  One-time backfill to re-sync streams that were synced before the new fields were added.

  REQUIRES explicit cutoff date for idempotency. Reuses shared Analytics module
  for pagination, session matching, and attribute building.

  Usage:
    mix tiktok.backfill_stream_analytics <brand_id> --cutoff "2026-02-18T00:00:00Z" [--limit N]

  Options:
    --cutoff  REQUIRED. Only backfill streams synced before this datetime.
    --limit   Maximum streams to process per run (default: 100)
  """
  use Mix.Task

  alias SocialObjects.Repo
  alias SocialObjects.TiktokLive.Stream
  alias SocialObjects.TiktokShop.Analytics

  import Ecto.Query

  @backfill_update_fields [
    :analytics_synced_at,
    :official_likes,
    :official_comments,
    :official_shares,
    :official_new_followers,
    :official_unique_viewers,
    :official_avg_price_cents,
    :official_created_sku_orders,
    :official_products_sold_count,
    :official_products_added
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(args, strict: [cutoff: :string, limit: :integer])

    # Require explicit cutoff - no default to ensure idempotency
    cutoff_str = Keyword.get(opts, :cutoff) || raise "--cutoff is required"
    {:ok, cutoff, _} = DateTime.from_iso8601(cutoff_str)

    brand_id = parse_brand_id(args)
    limit = Keyword.get(opts, :limit, 100)

    streams = find_streams_to_backfill(brand_id, cutoff, limit)
    Mix.shell().info("Found #{length(streams)} streams to backfill (cutoff: #{cutoff_str})")

    if streams != [] do
      backfill_streams(brand_id, streams)
    end
  end

  defp find_streams_to_backfill(brand_id, cutoff, limit) do
    from(s in Stream,
      where: s.brand_id == ^brand_id,
      where: s.analytics_synced_at < ^cutoff,
      where: not is_nil(s.tiktok_live_id),
      order_by: [desc: s.started_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp backfill_streams(brand_id, streams) do
    {start_date, end_date} = calculate_date_range(streams)

    Mix.shell().info("Fetching sessions for date range: #{start_date} to #{end_date}")

    # Use shared paginated fetch with rate limiting for backfill
    case Analytics.fetch_all_live_sessions(brand_id, start_date, end_date, rate_limit_delay: 300) do
      {:ok, sessions} ->
        Mix.shell().info("Fetched #{length(sessions)} sessions from API")

        Enum.each(streams, &backfill_single_stream(brand_id, &1, sessions))

      {:error, :rate_limited} ->
        Mix.shell().error("Rate limited - try again later")

      {:error, reason} ->
        Mix.shell().error("API error: #{inspect(reason)}")
    end
  end

  defp backfill_single_stream(brand_id, stream, sessions) do
    case Analytics.find_matching_session(stream, sessions) do
      :no_match ->
        Mix.shell().info("No session found for stream #{stream.id}")

      {:ok, session} ->
        update_stream_with_session(brand_id, stream, session)
    end
  end

  defp update_stream_with_session(brand_id, stream, session) do
    synced_at = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      Analytics.build_stream_analytics_attrs(session, synced_at)
      |> Map.take(@backfill_update_fields)

    from(s in Stream, where: s.brand_id == ^brand_id and s.id == ^stream.id)
    |> Repo.update_all(set: Enum.to_list(attrs))

    Mix.shell().info("Updated stream #{stream.id}")
  end

  defp calculate_date_range(streams) do
    earliest = Enum.min_by(streams, & &1.started_at, DateTime) |> Map.get(:started_at)
    latest = Enum.max_by(streams, & &1.ended_at, DateTime) |> Map.get(:ended_at)
    start_date = earliest |> DateTime.add(-1, :day) |> DateTime.to_date() |> Date.to_iso8601()
    end_date = latest |> DateTime.add(2, :day) |> DateTime.to_date() |> Date.to_iso8601()
    {start_date, end_date}
  end

  defp parse_brand_id([id | _]), do: String.to_integer(id)
  defp parse_brand_id([]), do: raise("brand_id is required")
end
