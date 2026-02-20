defmodule Mix.Tasks.Creators.BackfillTouchpointsTest do
  use SocialObjects.DataCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Creators.BackfillTouchpoints, as: BackfillTouchpointsTask
  alias SocialObjects.Creators
  alias SocialObjects.Outreach.OutreachLog

  setup do
    Mix.Task.reenable("creators.backfill_touchpoints")
    :ok
  end

  test "backfills latest successful touchpoint per brand/creator" do
    brand = brand_fixture()

    {:ok, creator} =
      Creators.create_creator(%{
        tiktok_username: "backfill-touchpoint-#{System.unique_integer([:positive])}"
      })

    _ = Creators.add_creator_to_brand(creator.id, brand.id)

    old_sent = DateTime.utc_now() |> DateTime.add(-7200, :second) |> DateTime.truncate(:second)

    new_delivered =
      DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    newest_failed = DateTime.utc_now() |> DateTime.truncate(:second)

    insert_outreach_log!(brand.id, creator.id, :email, :sent, old_sent)
    insert_outreach_log!(brand.id, creator.id, :sms, :delivered, new_delivered)
    insert_outreach_log!(brand.id, creator.id, :sms, :failed, newest_failed)

    _output =
      capture_io(fn ->
        BackfillTouchpointsTask.run([])
      end)

    bc = Creators.get_brand_creator(brand.id, creator.id)
    assert bc.last_touchpoint_type == :sms
    assert DateTime.compare(bc.last_touchpoint_at, new_delivered) == :eq
  end

  test "supports filtering by --brand-id" do
    brand_a = brand_fixture()
    brand_b = brand_fixture()

    {:ok, creator_a} =
      Creators.create_creator(%{
        tiktok_username: "backfill-brand-a-#{System.unique_integer([:positive])}"
      })

    {:ok, creator_b} =
      Creators.create_creator(%{
        tiktok_username: "backfill-brand-b-#{System.unique_integer([:positive])}"
      })

    _ = Creators.add_creator_to_brand(creator_a.id, brand_a.id)
    _ = Creators.add_creator_to_brand(creator_b.id, brand_b.id)

    sent_at = DateTime.utc_now() |> DateTime.truncate(:second)

    insert_outreach_log!(brand_a.id, creator_a.id, :email, :sent, sent_at)
    insert_outreach_log!(brand_b.id, creator_b.id, :sms, :sent, sent_at)

    _output =
      capture_io(fn ->
        BackfillTouchpointsTask.run(["--brand-id", Integer.to_string(brand_a.id)])
      end)

    bc_a = Creators.get_brand_creator(brand_a.id, creator_a.id)
    bc_b = Creators.get_brand_creator(brand_b.id, creator_b.id)

    assert bc_a.last_touchpoint_type == :email
    assert DateTime.compare(bc_a.last_touchpoint_at, sent_at) == :eq
    assert is_nil(bc_b.last_touchpoint_at)
  end

  defp insert_outreach_log!(brand_id, creator_id, channel, status, sent_at) do
    %OutreachLog{brand_id: brand_id}
    |> OutreachLog.changeset(%{
      creator_id: creator_id,
      channel: channel,
      status: status,
      sent_at: sent_at
    })
    |> Repo.insert!()
  end
end
