defmodule Mix.Tasks.Creators.BackfillTouchpoints do
  @moduledoc """
  Backfills `brand_creators.last_touchpoint_*` from the latest successful outreach logs.
  """

  @shortdoc "Backfills brand_creator touchpoint summary from outreach logs"

  use Mix.Task

  import Ecto.Query

  alias SocialObjects.Creators
  alias SocialObjects.Outreach.OutreachLog
  alias SocialObjects.Repo

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [brand_id: :integer])
    brand_id_filter = Keyword.get(opts, :brand_id)

    logs_query =
      from(ol in OutreachLog,
        where: ol.status in [:sent, :delivered],
        where: ol.channel in [:email, :sms],
        order_by: [asc: ol.brand_id, asc: ol.creator_id, desc: ol.sent_at, desc: ol.id],
        distinct: [ol.brand_id, ol.creator_id],
        select: %{
          brand_id: ol.brand_id,
          creator_id: ol.creator_id,
          channel: ol.channel,
          sent_at: ol.sent_at
        }
      )

    logs_query =
      if is_integer(brand_id_filter) do
        where(logs_query, [ol], ol.brand_id == ^brand_id_filter)
      else
        logs_query
      end

    logs = Repo.all(logs_query)

    updated =
      Enum.reduce(logs, 0, fn log, acc ->
        touchpoint_type =
          case log.channel do
            :email -> :email
            :sms -> :sms
          end

        case Creators.record_outreach_touchpoint(
               log.brand_id,
               log.creator_id,
               touchpoint_type,
               log.sent_at
             ) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    Mix.shell().info("Backfilled #{updated} brand_creator touchpoint summaries")
  end
end
