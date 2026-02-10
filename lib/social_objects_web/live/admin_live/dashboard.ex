defmodule SocialObjectsWeb.AdminLive.Dashboard do
  @moduledoc """
  Admin dashboard with overview stats and quick actions.
  """
  use SocialObjectsWeb, :live_view

  import SocialObjectsWeb.AdminComponents

  alias SocialObjects.Accounts
  alias SocialObjects.Catalog

  @impl true
  def mount(_params, _session, socket) do
    brands = Catalog.list_brands()
    users = Accounts.list_all_users()
    feature_flags = SocialObjects.FeatureFlags.list_all()
    defined_flags = SocialObjects.FeatureFlags.defined_flags()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:brand_count, length(brands))
     |> assign(:user_count, length(users))
     |> assign(:feature_flags, feature_flags)
     |> assign(:defined_flags, defined_flags)}
  end

  @impl true
  def handle_event("toggle_flag", %{"flag" => flag_name}, socket) do
    current = Map.get(socket.assigns.feature_flags, flag_name, true)
    SocialObjects.FeatureFlags.set_flag(flag_name, !current)

    {:noreply,
     socket
     |> assign(:feature_flags, SocialObjects.FeatureFlags.list_all())
     |> put_flash(:info, "Feature flag updated")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <div class="admin-page__header">
        <h1 class="admin-page__title">Dashboard</h1>
      </div>

      <div class="admin-body">
        <div class="stat-cards">
          <.stat_card label="Brands" value={@brand_count} href={~p"/admin/brands"} />
          <.stat_card label="Users" value={@user_count} href={~p"/admin/users"} />
        </div>

        <div class="admin-panel">
          <div class="admin-panel__header">
            <h2 class="admin-panel__title">Quick Actions</h2>
          </div>
          <div class="admin-panel__body">
            <div class="quick-actions">
              <.button navigate={~p"/admin/users"} variant="primary">
                Manage Users
              </.button>
              <.button navigate={~p"/admin/brands"} variant="outline">
                Manage Brands
              </.button>
            </div>
          </div>
        </div>

        <div class="admin-panel">
          <div class="admin-panel__header">
            <h2 class="admin-panel__title">Feature Flags</h2>
          </div>
          <div class="admin-panel__body">
            <div class="feature-flags">
              <div :for={flag <- @defined_flags} class="feature-flag">
                <div class="feature-flag__info">
                  <span class="feature-flag__label">{flag.label}</span>
                  <span class="feature-flag__description">{flag.description}</span>
                </div>
                <button
                  type="button"
                  phx-click="toggle_flag"
                  phx-value-flag={flag.key}
                  class={"toggle " <> if(Map.get(@feature_flags, flag.key, true), do: "toggle--on", else: "toggle--off")}
                  role="switch"
                  aria-checked={to_string(Map.get(@feature_flags, flag.key, true))}
                >
                  <span class="toggle__track"><span class="toggle__thumb"></span></span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
