defmodule Pavoi.Communications.Slack do
  @moduledoc """
  Slack integration for sending stream reports via chat.postMessage API.

  Uses Slack Block Kit for rich message formatting.
  Requires SLACK_BOT_TOKEN environment variable (Bot User OAuth Token).
  Optionally configure SLACK_CHANNEL (defaults to #tiktok-live-reports).
  In dev, you can set SLACK_DEV_USER_ID to route messages to a DM instead.

  ## File Uploads

  Uses the new 3-step upload process (files.upload deprecated Nov 2025):
  1. files.getUploadURLExternal - get upload URL
  2. POST binary data to upload URL
  3. files.completeUploadExternal - complete and share to channel
  """

  require Logger

  @base_url "https://slack.com/api"
  @timeout 30_000
  @upload_timeout 60_000

  @doc """
  Sends a message to the configured Slack channel using Block Kit.

  ## Options
    - `:channel` - Override the default channel
    - `:text` - Fallback text for notifications (shows in mobile push, etc.)

  Returns `{:ok, :sent}` on success, `{:error, reason}` on failure.
  """
  def send_message(blocks, opts \\ []) do
    config = get_config(Keyword.get(opts, :brand_id))

    if config_valid?(config) do
      text = Keyword.get(opts, :text, "TikTok Live Stream Report")

      case resolve_channel(config, opts) do
        {:ok, channel} ->
          do_send_message(config.bot_token, channel, text, blocks)

        {:error, reason} ->
          {:error, reason}
      end
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
      receive_timeout: @timeout
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
  def configured?(opts \\ []) do
    config = get_config(Keyword.get(opts, :brand_id))
    config_valid?(config)
  end

  @doc """
  Uploads an image to the configured Slack channel.

  Uses the new 3-step upload API:
  1. Get upload URL from Slack
  2. POST binary data to that URL
  3. Complete upload and share to channel

  ## Parameters
    - `binary` - The image binary data
    - `filename` - Name for the file (e.g., "stream_cover.jpg")
    - `opts` - Options:
      - `:channel` - Override the default channel
      - `:title` - Display title for the image
      - `:initial_comment` - Optional message to accompany the image

  Returns `{:ok, file_id}` on success, `{:error, reason}` on failure.
  """
  def upload_image(binary, filename, opts \\ []) do
    config = get_config(Keyword.get(opts, :brand_id))

    if config_valid?(config) do
      title = Keyword.get(opts, :title, filename)
      initial_comment = Keyword.get(opts, :initial_comment)

      with {:ok, channel} <- resolve_channel(config, opts),
           {:ok, upload_url, file_id} <-
             get_upload_url(config.bot_token, filename, byte_size(binary)),
           :ok <- upload_to_url(upload_url, binary),
           {:ok, _file} <-
             complete_upload(config.bot_token, file_id, channel, title, initial_comment) do
        Logger.info("Slack image uploaded to #{channel}, file_id: #{file_id}")
        {:ok, file_id}
      end
    else
      {:error, "Slack not configured - missing bot token"}
    end
  end

  # Step 1: Get upload URL from Slack
  defp get_upload_url(token, filename, length) do
    url = "#{@base_url}/files.getUploadURLExternal"

    req_opts = [
      url: url,
      form: [filename: filename, length: length],
      headers: [{"Authorization", "Bearer #{token}"}],
      finch: Pavoi.Finch,
      receive_timeout: @timeout
    ]

    case Req.post(req_opts) do
      {:ok,
       %{status: 200, body: %{"ok" => true, "upload_url" => upload_url, "file_id" => file_id}}} ->
        {:ok, upload_url, file_id}

      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        Logger.error("Slack getUploadURLExternal error: #{error}")
        {:error, "Failed to get upload URL: #{error}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP error getting upload URL: #{status}"}

      {:error, exception} ->
        {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  # Step 2: Upload binary data to the URL
  defp upload_to_url(upload_url, binary) do
    req_opts = [
      url: upload_url,
      body: binary,
      headers: [{"Content-Type", "application/octet-stream"}],
      finch: Pavoi.Finch,
      receive_timeout: @upload_timeout
    ]

    case Req.post(req_opts) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Slack upload failed (#{status}): #{inspect(body)}")
        {:error, "Upload failed with status #{status}"}

      {:error, exception} ->
        {:error, "Upload request failed: #{Exception.message(exception)}"}
    end
  end

  # Step 3: Complete upload and share to channel
  defp complete_upload(token, file_id, channel, title, initial_comment) do
    url = "#{@base_url}/files.completeUploadExternal"

    files = [%{id: file_id, title: title}]

    body =
      %{files: files, channel_id: channel}
      |> maybe_add(:initial_comment, initial_comment)

    req_opts = [
      url: url,
      json: body,
      headers: [{"Authorization", "Bearer #{token}"}],
      finch: Pavoi.Finch,
      receive_timeout: @timeout
    ]

    case Req.post(req_opts) do
      {:ok, %{status: 200, body: %{"ok" => true, "files" => [file | _]}}} ->
        {:ok, file}

      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        Logger.error("Slack completeUploadExternal error: #{error}")
        {:error, "Failed to complete upload: #{error}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP error completing upload: #{status}"}

      {:error, exception} ->
        {:error, "Complete request failed: #{Exception.message(exception)}"}
    end
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp resolve_channel(config, opts) do
    if dev_mode?() do
      case config.dev_user_id do
        id when id in [nil, ""] ->
          {:error, "Slack dev user id not configured"}

        user_id ->
          open_dm_channel(config.bot_token, user_id)
      end
    else
      fallback_channel = Keyword.get(opts, :channel, config.channel)
      {:ok, fallback_channel}
    end
  end

  defp open_dm_channel(token, user_id) do
    url = "#{@base_url}/conversations.open"

    req_opts = [
      url: url,
      json: %{users: user_id},
      headers: [{"Authorization", "Bearer #{token}"}],
      finch: Pavoi.Finch,
      receive_timeout: @timeout
    ]

    case Req.post(req_opts) do
      {:ok, %{status: 200, body: %{"ok" => true, "channel" => %{"id" => channel_id}}}} ->
        {:ok, channel_id}

      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        {:error, "Slack conversations.open error: #{error}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Slack conversations.open HTTP error: #{status} #{normalize_body(body)}"}

      {:error, exception} ->
        {:error, "Slack conversations.open request failed: #{Exception.message(exception)}"}
    end
  end

  defp get_config(brand_id) do
    %{
      bot_token: Pavoi.Settings.get_slack_bot_token(brand_id),
      channel: Pavoi.Settings.get_slack_channel(brand_id),
      dev_user_id: Pavoi.Settings.get_slack_dev_user_id(brand_id)
    }
  end

  defp dev_mode? do
    Application.get_env(:pavoi, :dev_routes, false)
  end

  defp config_valid?(config) do
    config.bot_token && config.bot_token != ""
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body), do: Jason.encode!(body)
  defp normalize_body(body), do: inspect(body)
end
