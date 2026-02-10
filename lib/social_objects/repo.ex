defmodule SocialObjects.Repo do
  use Ecto.Repo,
    otp_app: :social_objects,
    adapter: Ecto.Adapters.Postgres
end
