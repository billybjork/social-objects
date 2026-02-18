defmodule SocialObjects.Repo.Migrations.ClearCorrelatedStreamGmv do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE tiktok_streams
    SET gmv_cents = NULL,
        gmv_order_count = NULL,
        gmv_hourly = NULL
    WHERE gmv_cents IS NOT NULL
       OR gmv_order_count IS NOT NULL
       OR gmv_hourly IS NOT NULL
    """)
  end

  def down, do: :ok
end
