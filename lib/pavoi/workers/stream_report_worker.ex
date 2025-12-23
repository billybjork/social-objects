defmodule Pavoi.Workers.StreamReportWorker do
  @moduledoc """
  Oban worker that generates and sends Slack reports when TikTok Live streams end.

  The report includes:
  - Stream statistics (duration, viewers, likes, gifts, comments)
  - Top 5 products referenced in comments
  - Flash sale activity summary
  - AI-powered sentiment analysis of comments

  ## Job Arguments
  - `stream_id` - ID of the completed stream
  """

  use Oban.Worker,
    queue: :slack,
    max_attempts: 3,
    unique: [period: 300, keys: [:stream_id]]

  require Logger

  alias Pavoi.Communications.Slack
  alias Pavoi.StreamReport

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"stream_id" => stream_id}}) do
    Logger.info("Generating stream report for stream #{stream_id}")

    with {:ok, report_data} <- StreamReport.generate(stream_id),
         {:ok, blocks} <- StreamReport.format_slack_blocks(report_data),
         {:ok, :sent} <- send_slack_message(blocks, report_data) do
      Logger.info("Stream report sent successfully for stream #{stream_id}")
      :ok
    else
      {:error, "Slack not configured" <> _} = error ->
        # Slack not configured - log warning but don't retry
        Logger.warning("Skipping stream report - Slack not configured")
        {:cancel, error}

      {:error, reason} ->
        Logger.error("Failed to send stream report for stream #{stream_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_slack_message(blocks, report_data) do
    fallback_text = build_fallback_text(report_data)
    Slack.send_message(blocks, text: fallback_text)
  end

  # Build a simple text fallback for notifications
  defp build_fallback_text(report_data) do
    stream = report_data.stream
    stats = report_data.stats

    "Stream Report: @#{stream.unique_id} - " <>
      "#{stats.duration_formatted}, " <>
      "#{stats.peak_viewers} peak viewers, " <>
      "#{stats.total_comments} comments"
  end
end
