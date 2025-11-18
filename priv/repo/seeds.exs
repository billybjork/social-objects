# Seeds for Pavoi
# Run: mix run priv/repo/seeds.exs

alias Pavoi.Repo
alias Pavoi.Catalog.{Brand, Product, ProductImage, ProductVariant}
alias Pavoi.Sessions.{Session, SessionProduct, SessionState}
alias Pavoi.AI.TalkingPointsGeneration

require Logger

IO.puts("Clearing all data...")

# Clear all tables
Repo.delete_all(TalkingPointsGeneration)
Repo.delete_all(SessionState)
Repo.delete_all(SessionProduct)
Repo.delete_all(Session)
Repo.delete_all(ProductVariant)
Repo.delete_all(ProductImage)
Repo.delete_all(Product)
Repo.delete_all(Brand)

IO.puts("✓ Database cleared")
