# Test various affiliate API path patterns
# Run with: mix run scripts/test_affiliate_paths.exs

alias Pavoi.TiktokShop

paths = [
  # Paths derived from doc URL names like "seller-search-creator-on-marketplace-202509"
  {"/affiliate/202509/seller/search_creator_marketplace", :post},
  {"/affiliate/202509/sellers/creators/marketplace/search", :post},

  # From: get-marketplace-creator-performance-202509
  {"/affiliate/202509/marketplace/creator/performance", :get},
  {"/affiliate/202509/marketplace/creator/performance", :post},
  {"/affiliate/202509/creators/marketplace/performance", :get},

  # From: create-open-collaboration-202509
  {"/affiliate/202509/open_collaboration/create", :post},
  {"/affiliate/202509/open_collaborations/create", :post},

  # From: generate-target-collaboration-link-202509
  {"/affiliate/202509/target_collaboration/link/generate", :post},
  {"/affiliate/202509/target_collaborations/link/generate", :post},
  {"/affiliate/202509/target_collaboration_link/generate", :post},

  # From: generate-affiliate-product-promotion-link-202509
  {"/affiliate/202509/product/promotion_link/generate", :post},
  {"/affiliate/202509/products/promotion_link/generate", :post},
  {"/affiliate/202509/affiliate_product_promotion_link/generate", :post},

  # From: search-creator-affiliate-orders-202509
  {"/affiliate/202509/creator/orders/search", :post},
  {"/affiliate/202509/creators/affiliate_orders/search", :post},

  # From: create-target-collaboration-202509
  {"/affiliate/202509/target_collaboration/create", :post},
  {"/affiliate/202509/target_collaborations/create", :post},

  # From: edit-open-collaboration-settings-202509
  {"/affiliate/202509/open_collaboration/settings/edit", :post},
  {"/affiliate/202509/open_collaborations/settings", :post},
  {"/affiliate/202509/open_collaborations/settings", :get},

  # From: seller-review-sample-applications-202509
  {"/affiliate/202509/seller/sample_applications/review", :post},
  {"/affiliate/202509/sample_applications/review", :post},

  # From: search-open-collaboration-202509 (for products)
  {"/affiliate/202509/open_collaboration/search", :post},
  {"/affiliate/202509/open_collaborations/search", :post},

  # From: remove-open-collaboration-202509
  {"/affiliate/202509/open_collaboration/remove", :post},
  {"/affiliate/202509/open_collaborations/remove", :post},

  # Alternative: maybe the version is in the middle like products
  {"/seller/affiliate/202509/creators/search", :post},
  {"/seller/affiliate/202509/open_collaborations", :get},
]

IO.puts("Testing #{length(paths)} path variations...\n")

results = Enum.map(paths, fn {path, method} ->
  result = TiktokShop.make_api_request(method, path, %{page_size: 10}, %{})

  case result do
    {:ok, %{"code" => 0} = response} ->
      IO.puts("✅ SUCCESS: #{method |> to_string() |> String.upcase()} #{path}")
      IO.puts("   Data keys: #{inspect(Map.keys(Map.get(response, "data", %{})))}")
      {:success, path}

    {:ok, %{"code" => code, "message" => msg}} when code != 40006 ->
      IO.puts("⚠️  [#{code}] #{method |> to_string() |> String.upcase()} #{path}")
      IO.puts("   Message: #{msg}")
      {:api_error, path, code, msg}

    {:ok, %{"code" => 40006}} ->
      # Path not found - skip
      {:not_found, path}

    {:error, reason} when is_binary(reason) ->
      if not String.contains?(reason, "40006") do
        IO.puts("❓ #{method |> to_string() |> String.upcase()} #{path}")
        IO.puts("   Error: #{String.slice(reason, 0, 100)}")
        {:error, path, reason}
      else
        {:not_found, path}
      end

    _ ->
      {:unknown, path}
  end
end)

# Summary
successes = Enum.filter(results, fn r -> elem(r, 0) == :success end)
api_errors = Enum.filter(results, fn r -> elem(r, 0) == :api_error end)
not_found = Enum.filter(results, fn r -> elem(r, 0) == :not_found end)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("SUMMARY")
IO.puts(String.duplicate("=", 60))
IO.puts("✅ Success: #{length(successes)}")
IO.puts("⚠️  API errors (valid path, wrong params/perms): #{length(api_errors)}")
IO.puts("❌ Not found (40006): #{length(not_found)}")

if length(api_errors) > 0 do
  IO.puts("\nAPI Errors (these are valid paths!):")
  Enum.each(api_errors, fn {_, path, code, msg} ->
    IO.puts("  #{path}: [#{code}] #{msg}")
  end)
end
