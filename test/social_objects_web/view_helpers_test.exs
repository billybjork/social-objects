defmodule SocialObjectsWeb.ViewHelpersTest do
  use ExUnit.Case, async: true

  import SocialObjectsWeb.ViewHelpers

  describe "format_metric/1" do
    test "returns dash for nil" do
      assert format_metric(nil) == "-"
    end

    test "returns zero for 0" do
      assert format_metric(0) == "0"
    end

    test "formats positive integers with thousand separators" do
      assert format_metric(1234) == "1,234"
    end

    test "returns dash for non-integer values" do
      assert format_metric("string") == "-"
      assert format_metric(12.5) == "-"
    end
  end

  describe "format_gmv_or_dash/1" do
    test "returns dash for nil" do
      assert format_gmv_or_dash(nil) == "-"
    end

    test "formats zero as $0" do
      assert format_gmv_or_dash(0) == "$0"
    end

    test "formats cents as dollars" do
      assert format_gmv_or_dash(12_345) == "$123"
    end

    test "formats large values with k suffix" do
      # 150_000 cents = $1,500 -> "$1.5k"
      assert format_gmv_or_dash(150_000) == "$1.5k"
    end

    test "formats Decimal values" do
      assert format_gmv_or_dash(Decimal.new("12345")) == "$123"
    end
  end

  describe "format_gmv/1" do
    test "returns $0 for nil (cumulative context)" do
      assert format_gmv(nil) == "$0"
    end

    test "returns $0 for 0" do
      assert format_gmv(0) == "$0"
    end

    test "formats cents as dollars" do
      assert format_gmv(9900) == "$99"
    end

    test "formats large values with k suffix" do
      assert format_gmv(150_000) == "$1.5k"
    end
  end

  describe "format_number/1" do
    test "returns 0 for nil" do
      assert format_number(nil) == "0"
    end

    test "formats numbers with thousand separators" do
      assert format_number(1234) == "1,234"
      assert format_number(1_234_567) == "1,234,567"
    end

    test "handles small numbers" do
      assert format_number(123) == "123"
    end
  end
end
