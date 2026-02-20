defmodule Mix.Tasks.Creators.BackfillVideoMetrics do
  @moduledoc """
  Backfills video metric snapshots and all-time metric baselines for a brand.

  This task is idempotent:
  - `creator_videos` all-time metrics are monotonic and never regress.
  - `creator_video_metric_snapshots` are upserted by
    `{brand_id, tiktok_video_id, snapshot_date, window_days}`.

  Usage:
    mix creators.backfill_video_metrics <brand_id> [--snapshot-date YYYY-MM-DD] [--source-run-id ID] [--with-thumbnails]

  Options:
    --snapshot-date    Snapshot date override (default: today UTC)
    --source-run-id    Optional run id for observability
    --with-thumbnails  Also fetch thumbnail assets during the run (default: false)
  """

  use Mix.Task

  alias SocialObjects.Workers.VideoSyncWorker

  @shortdoc "Backfill /videos snapshots + all-time metrics for a brand"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [snapshot_date: :string, source_run_id: :string, with_thumbnails: :boolean]
      )

    brand_id = parse_brand_id(positional)
    snapshot_date = parse_snapshot_date(Keyword.get(opts, :snapshot_date))

    source_run_id =
      Keyword.get(
        opts,
        :source_run_id,
        "backfill-#{brand_id}-#{Date.utc_today() |> Date.to_iso8601()}"
      )

    skip_thumbnails? = !Keyword.get(opts, :with_thumbnails, false)

    Mix.shell().info("Starting video metric backfill for brand_id=#{brand_id}")
    Mix.shell().info("snapshot_date=#{snapshot_date} source_run_id=#{source_run_id}")

    case VideoSyncWorker.run_sync(brand_id,
           snapshot_date: snapshot_date,
           source_run_id: source_run_id,
           skip_thumbnails?: skip_thumbnails?
         ) do
      {:ok, stats} ->
        print_stats(stats)

      {:snooze, seconds} ->
        Mix.shell().error("Backfill rate-limited. Retry after #{seconds} seconds")

      {:error, reason} ->
        Mix.shell().error("Backfill failed: #{inspect(reason)}")
    end
  end

  defp parse_brand_id([brand_id | _]), do: String.to_integer(brand_id)
  defp parse_brand_id([]), do: raise("brand_id is required")

  defp parse_snapshot_date(nil), do: Date.utc_today()

  defp parse_snapshot_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> raise("invalid --snapshot-date (expected YYYY-MM-DD)")
    end
  end

  defp print_stats(stats) do
    Mix.shell().info("Backfill complete")
    Mix.shell().info("  videos_synced: #{stats.videos_synced}")
    Mix.shell().info("  creators_created: #{stats.creators_created}")
    Mix.shell().info("  creators_matched: #{stats.creators_matched}")
    Mix.shell().info("  duplicate_rows: #{stats.duplicate_rows}")
    Mix.shell().info("  conflict_video_count: #{stats.conflict_video_count}")
    Mix.shell().info("  max_conflict_gmv_cents: #{stats.max_conflict_gmv_cents}")

    Enum.each(stats.snapshot_stats, fn {window_days, window_stats} ->
      Mix.shell().info(
        "  snapshots_#{window_days}d: inserted=#{window_stats.inserted} updated=#{window_stats.updated} skipped=#{window_stats.skipped}"
      )
    end)
  end
end
