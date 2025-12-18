defmodule Pavoi.TiktokLive.StreamReconciler do
  @moduledoc """
  Reconciles stream state on application startup.

  Finds streams that are marked as "capturing" but have no active Oban worker,
  which can happen after application restarts or crashes. These orphaned streams
  are marked as "ended" to maintain data integrity.
  """

  require Logger

  alias Pavoi.Repo
  alias Pavoi.TiktokLive.Stream

  import Ecto.Query

  @doc """
  Runs stream reconciliation. Should be called on application startup.

  Returns the number of streams that were reconciled.
  """
  def run do
    orphaned_streams = find_orphaned_capturing_streams()

    if Enum.empty?(orphaned_streams) do
      Logger.debug("Stream reconciliation: no orphaned streams found")
      0
    else
      Logger.info("Stream reconciliation: found #{length(orphaned_streams)} orphaned streams")

      Enum.each(orphaned_streams, fn stream ->
        mark_stream_ended(stream)
      end)

      length(orphaned_streams)
    end
  end

  @doc """
  Finds streams marked as "capturing" that don't have an active Oban job.
  """
  def find_orphaned_capturing_streams do
    # Get all capturing streams
    capturing_streams =
      Stream
      |> where([s], s.status == :capturing)
      |> Repo.all()

    # Get active Oban job stream IDs
    active_job_stream_ids = get_active_job_stream_ids()

    # Filter to streams without active jobs
    Enum.reject(capturing_streams, fn stream ->
      stream.id in active_job_stream_ids
    end)
  end

  defp get_active_job_stream_ids do
    # Query Oban jobs for our worker that are in active states
    query = """
    SELECT args->>'stream_id' as stream_id
    FROM oban_jobs
    WHERE worker = 'Pavoi.Workers.TiktokLiveStreamWorker'
      AND state IN ('available', 'scheduled', 'executing', 'retryable')
    """

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [id] -> String.to_integer(id) end)
        |> MapSet.new()

      {:error, _} ->
        MapSet.new()
    end
  end

  defp mark_stream_ended(stream) do
    Logger.info(
      "Marking orphaned stream #{stream.id} (@#{stream.unique_id}) as ended"
    )

    stream
    |> Stream.changeset(%{
      status: :ended,
      ended_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end
end
