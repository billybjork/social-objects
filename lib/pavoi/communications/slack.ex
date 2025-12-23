defmodule Pavoi.Communications.Slack do
  @moduledoc """
  Slack integration for sending stream reports via chat.postMessage API.

  Uses Slack Block Kit for rich message formatting.
  Requires SLACK_BOT_TOKEN environment variable (Bot User OAuth Token).
  Optionally configure SLACK_CHANNEL (defaults to #tiktok-live-reports).
  """

  require Logger

  @base_url "https://slack.com/api"
  @timeout 30_000

  @doc """
  Sends a message to the configured Slack channel using Block Kit.

  ## Options
    - `:channel` - Override the default channel
    - `:text` - Fallback text for notifications (shows in mobile push, etc.)

  Returns `{:ok, :sent}` on success, `{:error, reason}` on failure.
  """
  def send_message(blocks, opts \\ []) do
    config = get_config()

    if config_valid?(config) do
      channel = Keyword.get(opts, :channel, config.channel)
      text = Keyword.get(opts, :text, "TikTok Live Stream Report")

      do_send_message(config.bot_token, channel, text, blocks)
    else
      {:error, "Slack not configured - missing bot token"}
    end
  end

  defp do_send_message(token, channel, text, blocks) do
    url = "#{@base_url}/chat.postMessage"

    body = %{
      channel: channel,
      text: text,
      blocks: blocks
    }

    req_opts = [
      url: url,
      json: body,
      headers: [{"Authorization", "Bearer #{token}"}],
      finch: Pavoi.Finch,
      receive_timeout: @timeout,
      connect_options: [timeout: @timeout]
    ]

    case Req.post(req_opts) do
      {:ok, %{status: 200, body: %{"ok" => true} = response}} ->
        ts = get_in(response, ["ts"])
        Logger.info("Slack message sent to #{channel}, ts: #{ts}")
        {:ok, :sent}

      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        Logger.error("Slack API error for #{channel}: #{error}")
        {:error, "Slack API error: #{error}"}

      {:ok, %{status: status, body: body}} ->
        error = normalize_body(body)
        Logger.error("Slack HTTP error (#{status}) for #{channel}: #{error}")
        {:error, "Slack HTTP error: #{status}"}

      {:error, exception} ->
        Logger.error("Slack request failed for #{channel}: #{Exception.message(exception)}")
        {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  @doc """
  Checks if Slack is properly configured.
  """
  def configured? do
    config = get_config()
    config_valid?(config)
  end

  defp get_config do
    %{
      bot_token: Application.get_env(:pavoi, :slack_bot_token),
      channel: Application.get_env(:pavoi, :slack_channel, "#tiktok-live-reports")
    }
  end

  defp config_valid?(config) do
    config.bot_token && config.bot_token != ""
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body), do: Jason.encode!(body)
  defp normalize_body(body), do: inspect(body)
end
