defmodule Mix.Tasks.AuditAffiliateApi do
  @moduledoc """
  Audit new TikTok Shop Affiliate API endpoints to discover available data.

  Tests the following scopes:
  - seller.creator_marketplace.read - Search creators, get performance
  - seller.affiliate_collaboration.write - Manage collaborations

  ## Usage

      # Run full audit
      mix audit_affiliate_api

      # Test only creator marketplace endpoints
      mix audit_affiliate_api --scope marketplace

      # Test only collaboration endpoints
      mix audit_affiliate_api --scope collaboration

      # Verbose mode (show full response bodies)
      mix audit_affiliate_api --verbose
  """

  use Mix.Task
  require Logger

  alias Pavoi.TiktokShop

  @shortdoc "Audit TikTok Shop Affiliate API endpoints"

  # API versions vary by endpoint - discovered from docs:
  # - /affiliate_creator/202508/... for creator profiles
  # - /affiliate_creator/202405/... for open collaborations
  # - /affiliate_seller/... for seller endpoints (TBD)
  # - /order/202309/... for orders

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [scope: :string, verbose: :boolean],
        aliases: [s: :scope, v: :verbose]
      )

    scope = Keyword.get(opts, :scope, "all")
    verbose = Keyword.get(opts, :verbose, false)

    print_header()

    results =
      case scope do
        "marketplace" -> audit_marketplace_endpoints(verbose)
        "collaboration" -> audit_collaboration_endpoints(verbose)
        _ -> audit_marketplace_endpoints(verbose) ++ audit_collaboration_endpoints(verbose)
      end

    print_summary(results)
  end

  defp print_header do
    Mix.shell().info("""

    ╔══════════════════════════════════════════════════════════════════╗
    ║           TikTok Shop Affiliate API Audit                        ║
    ║           Discovering new endpoint capabilities                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
  end

  # ============================================================================
  # Creator Marketplace Endpoints (seller.creator_marketplace.read)
  # ============================================================================

  defp audit_marketplace_endpoints(verbose) do
    Mix.shell().info("""
    ┌──────────────────────────────────────────────────────────────────┐
    │  SCOPE: seller.creator_marketplace.read                         │
    └──────────────────────────────────────────────────────────────────┘
    """)

    # Verified paths from TikTok docs:
    # - /affiliate_seller/202406/marketplace_creators/search (POST, page_size must be 12 or 20)
    # - /affiliate_seller/202406/marketplace_creators/{creator_user_id} (GET)

    endpoints = [
      # Seller Search Creator on Marketplace (VERIFIED PATH)
      {:post, "/affiliate_seller/202406/marketplace_creators/search", %{page_size: 12}, %{},
       "Search Creators on Marketplace"},

      # Get Creator Performance (VERIFIED PATH) - needs a creator_user_id
      {:get, "/affiliate_seller/202406/marketplace_creators/test_user_id", %{}, %{},
       "Get Creator Performance (test)"}
    ]

    Enum.map(endpoints, fn {method, path, params, body, name} ->
      test_endpoint(method, path, params, body, name, verbose)
    end)
  end

  # ============================================================================
  # Collaboration Management Endpoints (seller.affiliate_collaboration.write)
  # ============================================================================

  defp audit_collaboration_endpoints(verbose) do
    Mix.shell().info("""
    ┌──────────────────────────────────────────────────────────────────┐
    │  SCOPE: seller.affiliate_collaboration.write                    │
    └──────────────────────────────────────────────────────────────────┘
    """)

    # Based on discovered paths:
    # /affiliate_creator/202405/open_collaborations/products/search
    # /order/202309/orders/search

    read_endpoints = [
      # Open collaborations - creator side (discovered: 202405)
      {:post, "/affiliate_creator/202405/open_collaborations/products/search", %{}, %{},
       "Search Open Collab Products (Creator)"},
      {:get, "/affiliate_creator/202405/open_collaborations", %{}, %{},
       "List Open Collaborations (Creator)"},
      {:post, "/affiliate_creator/202405/open_collaborations/search", %{}, %{},
       "Search Open Collaborations (Creator)"},

      # Open collaborations - seller side
      {:get, "/affiliate_seller/202405/open_collaborations", %{}, %{},
       "List Open Collaborations (Seller)"},
      {:post, "/affiliate_seller/202405/open_collaborations/search", %{}, %{},
       "Search Open Collaborations (Seller)"},
      {:get, "/affiliate_seller/202509/open_collaborations", %{}, %{},
       "List Open Collaborations (Seller 202509)"},

      # Target collaborations
      {:get, "/affiliate_seller/202405/target_collaborations", %{}, %{},
       "List Target Collaborations (Seller)"},
      {:post, "/affiliate_seller/202405/target_collaborations/search", %{}, %{},
       "Search Target Collaborations (Seller)"},
      {:get, "/affiliate_creator/202405/target_collaborations", %{}, %{},
       "List Target Collaborations (Creator)"},

      # Sample applications
      {:get, "/affiliate_seller/202405/sample_applications", %{}, %{},
       "List Sample Applications (Seller)"},
      {:post, "/affiliate_seller/202405/sample_applications/search", %{}, %{},
       "Search Sample Applications (Seller)"},
      {:get, "/affiliate_creator/202405/sample_applications", %{}, %{},
       "List Sample Applications (Creator)"},

      # Orders - discovered: /order/202309/orders/search
      {:post, "/order/202309/orders/search", %{}, %{},
       "Search Orders (202309)"},
      {:get, "/order/202309/orders", %{}, %{},
       "List Orders (202309)"},

      # Affiliate orders specifically
      {:post, "/affiliate_seller/202405/orders/search", %{}, %{},
       "Search Affiliate Orders (Seller)"},
      {:post, "/affiliate_creator/202405/orders/search", %{}, %{},
       "Search Affiliate Orders (Creator)"}
    ]

    write_endpoints = [
      # Open collaboration management
      {:post, "/affiliate_seller/202405/open_collaborations", %{}, %{},
       "Create Open Collaboration (Seller)"},
      {:post, "/affiliate_seller/202509/open_collaborations", %{}, %{},
       "Create Open Collaboration (Seller 202509)"},

      # Target collaboration management
      {:post, "/affiliate_seller/202405/target_collaborations", %{}, %{},
       "Create Target Collaboration (Seller)"},

      # Promotion links
      {:post, "/affiliate_seller/202405/products/promotion_link", %{}, %{},
       "Generate Promotion Link (Seller)"},
      {:post, "/affiliate_seller/202509/promotion_links", %{}, %{},
       "Generate Promotion Link (202509)"},

      # Product activation - discovered: /product/202309/products/activate
      {:post, "/product/202309/products/activate", %{}, %{},
       "Activate Products"}
    ]

    read_results = Enum.map(read_endpoints, fn {method, path, params, body, name} ->
      test_endpoint(method, path, params, body, name, verbose)
    end)

    Mix.shell().info("\n  --- Write Endpoints (probing for schema) ---\n")

    write_results = Enum.map(write_endpoints, fn {method, path, params, body, name} ->
      test_endpoint(method, path, params, body, name, verbose)
    end)

    read_results ++ write_results
  end

  # ============================================================================
  # Endpoint Testing
  # ============================================================================

  defp test_endpoint(method, path, params, body, name, verbose) do
    Mix.shell().info("  Testing: #{name}")
    Mix.shell().info("    #{method |> to_string() |> String.upcase()} #{path}")

    result = TiktokShop.make_api_request(method, path, params, body)

    case result do
      {:ok, response} ->
        handle_success(response, name, verbose)

      {:error, reason} ->
        handle_error(reason, name, verbose)
    end
  end

  defp handle_success(response, name, verbose) do
    # Check if it's a TikTok error response (code != 0)
    case response do
      %{"code" => 0, "data" => data} ->
        Mix.shell().info("    ✅ SUCCESS")
        print_data_summary(data, verbose)
        {:success, name, data}

      %{"code" => code, "message" => message} ->
        Mix.shell().info("    ⚠️  API Error: [#{code}] #{message}")
        if verbose, do: print_full_response(response)
        {:api_error, name, code, message}

      _ ->
        Mix.shell().info("    ✅ Response received")
        if verbose, do: print_full_response(response)
        {:success, name, response}
    end
  end

  defp handle_error(reason, name, verbose) do
    error_str = if is_binary(reason), do: reason, else: inspect(reason)
    Mix.shell().info("    ❌ Error: #{truncate(error_str, 100)}")

    # Extract useful info from error messages
    cond do
      String.contains?(error_str, "Invalid path") ->
        Mix.shell().info("       → Path not found")

      String.contains?(error_str, "scope") or String.contains?(error_str, "permission") ->
        Mix.shell().info("       → Scope/permission issue")

      String.contains?(error_str, "required") ->
        # This is actually useful - tells us what params are needed
        Mix.shell().info("       → Missing required parameters (check full error)")
        if verbose, do: Mix.shell().info("       Full: #{error_str}")

      true ->
        :ok
    end

    if verbose and not String.contains?(error_str, "Invalid path") do
      Mix.shell().info("       Full: #{error_str}")
    end

    Mix.shell().info("")
    {:error, name, reason}
  end

  defp print_data_summary(data, verbose) when is_map(data) do
    keys = Map.keys(data)
    Mix.shell().info("    Data keys: #{Enum.join(keys, ", ")}")

    # Show counts for list fields
    Enum.each(data, fn {key, value} ->
      case value do
        list when is_list(list) ->
          Mix.shell().info("      #{key}: #{length(list)} items")

          if verbose and length(list) > 0 do
            first = List.first(list)

            if is_map(first) do
              Mix.shell().info("        First item keys: #{Map.keys(first) |> Enum.join(", ")}")
            end
          end

        _ ->
          :ok
      end
    end)

    if verbose, do: print_full_response(data)
    Mix.shell().info("")
  end

  defp print_data_summary(data, verbose) do
    if verbose, do: print_full_response(data)
    Mix.shell().info("")
  end

  defp print_full_response(data) do
    json = Jason.encode!(data, pretty: true)
    # Limit output
    lines = String.split(json, "\n")

    if length(lines) > 50 do
      truncated = Enum.take(lines, 50) |> Enum.join("\n")
      Mix.shell().info("\n#{truncated}\n    ... (truncated, #{length(lines)} total lines)")
    else
      Mix.shell().info("\n#{json}")
    end
  end

  # ============================================================================
  # Summary
  # ============================================================================

  defp print_summary(results) do
    successes = Enum.filter(results, fn r -> elem(r, 0) == :success end)
    api_errors = Enum.filter(results, fn r -> elem(r, 0) == :api_error end)
    errors = Enum.filter(results, fn r -> elem(r, 0) == :error end)

    Mix.shell().info("""

    ╔══════════════════════════════════════════════════════════════════╗
    ║                         AUDIT SUMMARY                            ║
    ╚══════════════════════════════════════════════════════════════════╝

    Total endpoints tested: #{length(results)}
    ✅ Successful: #{length(successes)}
    ⚠️  API Errors (valid path, permission/param issue): #{length(api_errors)}
    ❌ Failed (invalid path or network): #{length(errors)}
    """)

    if length(successes) > 0 do
      Mix.shell().info("  Working Endpoints:")

      Enum.each(successes, fn {_, name, _data} ->
        Mix.shell().info("    • #{name}")
      end)
    end

    if length(api_errors) > 0 do
      Mix.shell().info("\n  API Errors (likely valid paths, check permissions/params):")

      Enum.each(api_errors, fn {_, name, code, message} ->
        Mix.shell().info("    • #{name}: [#{code}] #{message}")
      end)
    end

    # Group errors by type
    path_errors = Enum.filter(errors, fn {_, _, reason} ->
      reason_str = if is_binary(reason), do: reason, else: inspect(reason)
      String.contains?(reason_str, "Invalid path") or String.contains?(reason_str, "404")
    end)

    other_errors = errors -- path_errors

    if length(other_errors) > 0 do
      Mix.shell().info("\n  Other Errors (investigate these):")

      Enum.each(other_errors, fn {_, name, reason} ->
        reason_str = if is_binary(reason), do: reason, else: inspect(reason)
        Mix.shell().info("    • #{name}: #{truncate(reason_str, 80)}")
      end)
    end

    Mix.shell().info("""

    ────────────────────────────────────────────────────────────────────
    Next Steps:
    1. For successful endpoints, review the data structure
    2. For API errors, check if you need additional scopes or params
    3. Run with --verbose for full response bodies
    ────────────────────────────────────────────────────────────────────
    """)
  end

  defp truncate(str, max_length) do
    if String.length(str) > max_length do
      String.slice(str, 0, max_length) <> "..."
    else
      str
    end
  end
end
