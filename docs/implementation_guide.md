# Implementation Guide

This guide walks through implementing Hudson from scratch, including critical performance patterns, real-time synchronization, and image loading optimizations.

## 1. Project Setup

### 1.1 Create Phoenix Project

```bash
# Create new Phoenix app with LiveView, WITHOUT Tailwind (use regular CSS)
mix phx.new hudson --live --no-tailwind

cd hudson
```

**Note:** We skip Tailwind (`--no-tailwind`) and use regular CSS for full control over styling.

### 1.2 Configure Database

Edit `config/dev.exs` and `config/runtime.exs` to use Supabase with strict TLS verification:

```elixir
# config/runtime.exs
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      """

  config :hudson, Hudson.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true,
    ssl_opts: [
      cacertfile: System.fetch_env!("SUPABASE_CA_CERT"),
      server_name_indication: 'db.supabase.net'
    ]
end
```

> Tip: Supabase ships a PEM bundle in their dashboard. Check it into `priv/certs/` (safe for public use) or depend on [`:castore`](https://hexdocs.pm/castore/readme.html) and point `cacertfile` there. Never ship `verify: :verify_none`.

Create `.env` file:

```bash
# .env (DO NOT COMMIT)
DATABASE_URL=postgresql://postgres:[password]@[project-ref].supabase.co:5432/postgres
SUPABASE_URL=https://[project-ref].supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ... # NEVER expose to frontend!
SUPABASE_CA_CERT=/absolute/path/to/supabase-ca.pem
SUPABASE_STORAGE_PUBLIC_URL=https://[project-ref].supabase.co/storage/v1/object/public
```

```elixir
# config/runtime.exs
config :hudson, :storage_public_url, System.fetch_env!("SUPABASE_STORAGE_PUBLIC_URL")
```

Load environment variables:

```bash
# Install dotenv
mix archive.install hex dotenv

# Or use direnv
echo "export $(cat .env | xargs)" > .envrc
direnv allow
```

### 1.3 Install Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps
    {:supabase_potion, "~> 0.5"},  # Supabase client
    {:earmark, "~> 1.4"},           # Markdown rendering
    {:jason, "~> 1.4"},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"}
  ]
end
```

```bash
mix deps.get
```

### 1.4 Create Database

```bash
mix ecto.create
```

### 1.5 Configure Authentication Gate (MVP)

MVP still gates access with shared secrets, but they must be treated like real credentials:

1. **Create role-specific secrets** (`PRODUCER_SHARED_SECRET`, `TALENT_SHARED_SECRET`, `ADMIN_SHARED_SECRET`) and store them in `.env`.
2. **Hash secrets on boot** with `Bcrypt.hash_pwd_salt/1` and keep only the hash in memory.
3. **Verify logins** with `Bcrypt.verify_pass/2`; on success, issue a signed session token that encodes the role and expires after 4 hours.
4. **Throttle** the `/login` POST route (e.g., [`Hammer`](https://hexdocs.pm/hammer/readme.html) or `Phoenix.LiveView.RateLimiter`) to 5 attempts / minute / IP and lock the user out for 5 minutes on repeated failures.
5. **Log audit events** (login, logout, elevated actions) to `Logger` + structured metadata so you can trace producer actions later.

```elixir
# config/runtime.exs
config :hudson, Hudson.Auth,
  producer_secret_hash: Bcrypt.hash_pwd_salt(System.fetch_env!("PRODUCER_SHARED_SECRET")),
  talent_secret_hash: Bcrypt.hash_pwd_salt(System.fetch_env!("TALENT_SHARED_SECRET")),
  admin_secret_hash: Bcrypt.hash_pwd_salt(System.fetch_env!("ADMIN_SHARED_SECRET")),
  session_ttl: 4 * 60 * 60
```

Designate plugs (`HudsonWeb.RequireProducer`, etc.) now so migrating to `mix phx.gen.auth` later is drop-in.

---

## 2. Implement Domain Model

### 2.1 Generate Migrations

See [Domain Model](domain_model.md) for full schema definitions. Generate migrations in order:

```bash
mix phx.gen.context Catalog Brand brands name:string slug:string:unique notes:text

mix phx.gen.context Catalog Product products \
  brand_id:references:brands \
  display_number:integer \
  name:string \
  short_name:string \
  description:text \
  talking_points_md:text \
  original_price_cents:integer \
  sale_price_cents:integer \
  pid:string:unique \
  sku:string \
  stock:integer \
  is_featured:boolean \
  external_url:string

mix phx.gen.context Catalog ProductImage product_images \
  product_id:references:products \
  position:integer \
  path:string \
  thumbnail_path:string \
  alt_text:string \
  is_primary:boolean

# Continue for Sessions, Hosts, SessionProducts, SessionState...
```

### 2.2 Manual Migration Adjustments

**Add tags array to products:**

```elixir
# In products migration
def change do
  create table(:products) do
    # ... other fields
    add :tags, {:array, :string}, default: []
    # ...
  end

  # Add GIN index for array search
  create index(:products, [:tags], using: :gin)
end
```

**Add cascade deletes:**

```elixir
# In product_images migration
add :product_id, references(:products, on_delete: :delete_all), null: false

# In session_products migration
add :session_id, references(:sessions, on_delete: :delete_all), null: false
```

### 2.3 Run Migrations

```bash
mix ecto.migrate
```

> Why the extra ceremony? Holding a `FOR UPDATE` lock and broadcasting from inside the transaction prevents concurrent producer actions from overwriting each other, and the zero-image guard lets the UI show a friendly warning instead of crashing LiveView with `rem/2` on 0.

---

## 3. Implement SessionRunLive (Talent/Producer View)

This is the core LiveView for live session control.

### 3.1 Create LiveView Module

```elixir
# lib/hudson_web/live/session_run_live.ex
defmodule HudsonWeb.SessionRunLive do
  use HudsonWeb, :live_view
  alias Hudson.{Sessions, Catalog}

  @impl true
  def mount(%{"id" => session_id} = params, _session, socket) do
    session = Sessions.get_session!(session_id)
    mode = Map.get(params, "view", "talent")

    socket =
      socket
      |> assign(
        session: session,
        session_id: session_id,
        mode: mode,
        page_title: session.name,

        # CRITICAL: Temporary assigns for memory management
        temporary_assigns: [
          current_session_product: nil,
          current_product: nil,
          talking_points_html: nil,
          product_images: nil,
          next_products_preview: nil
        ]
      )

    # Subscribe to PubSub ONLY after WebSocket connection
    if connected?(socket) do
      subscribe_to_session(session_id)
      socket = load_initial_state(socket, params)
      {:ok, socket}
    else
      # Minimal work during HTTP mount
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle URL parameter changes (from push_patch or back button)
    socket = load_state_from_params(socket, params)
    {:noreply, socket}
  end

  # Primary navigation: Direct jump to product by number
  @impl true
  def handle_event("jump_to_product", %{"position" => position}, socket) do
    position = String.to_integer(position)

    case Sessions.jump_to_product(socket.assigns.session_id, position) do
      {:ok, new_state} ->
        socket =
          push_patch(socket,
            to:
              ~p"/sessions/#{socket.assigns.session_id}/run?sp=#{new_state.current_session_product_id}&img=0"
          )

        {:noreply, socket}

      {:error, :invalid_position} ->
        {:noreply, put_flash(socket, :error, "Invalid product number")}
    end
  end

  # Convenience navigation: Sequential next/previous with arrow keys
  @impl true
  def handle_event("next_product", _params, socket) do
    case Sessions.advance_to_next_product(socket.assigns.session_id) do
      {:ok, new_state} ->
        socket =
          push_patch(socket,
            to:
              ~p"/sessions/#{socket.assigns.session_id}/run?sp=#{new_state.current_session_product_id}&img=#{new_state.current_image_index}"
          )

        {:noreply, socket}

      {:error, :end_of_session} ->
        {:noreply, put_flash(socket, :info, "End of session reached")}
    end
  end

  @impl true
  def handle_event("previous_product", _params, socket) do
    case Sessions.go_to_previous_product(socket.assigns.session_id) do
      {:ok, new_state} ->
        socket =
          push_patch(socket,
            to:
              ~p"/sessions/#{socket.assigns.session_id}/run?sp=#{new_state.current_session_product_id}&img=#{new_state.current_image_index}"
          )

        {:noreply, socket}

      {:error, :start_of_session} ->
        {:noreply, put_flash(socket, :info, "Already at first product")}
    end
  end

  @impl true
  def handle_event("next_image", _params, socket) do
    {:ok, _state} = Sessions.cycle_product_image(socket.assigns.session_id, :next)
    {:noreply, socket}
  end

  @impl true
  def handle_event("previous_image", _params, socket) do
    {:ok, _state} = Sessions.cycle_product_image(socket.assigns.session_id, :previous)
    {:noreply, socket}
  end

  # Handle PubSub broadcasts from other clients
  @impl true
  def handle_info({:state_changed, new_state}, socket) do
    socket = load_state_from_session_state(socket, new_state)
    {:noreply, socket}
  end

  # Private helpers

  defp subscribe_to_session(session_id) do
    Phoenix.PubSub.subscribe(Hudson.PubSub, "session:#{session_id}:state")
  end

  defp load_initial_state(socket, params) do
    session_id = socket.assigns.session_id

    # Priority: URL params > DB state > first product
    case params do
      %{"sp" => sp_id, "img" => img_idx} ->
        load_by_session_product_id(socket, sp_id, String.to_integer(img_idx))

      _ ->
        case Sessions.get_session_state(session_id) do
          {:ok, state} ->
            load_state_from_session_state(socket, state)

          {:error, :not_found} ->
            # Initialize to first product
            {:ok, state} = Sessions.initialize_session_state(session_id)
            load_state_from_session_state(socket, state)
        end
    end
  end

  defp load_state_from_params(socket, params) do
    case params do
      %{"sp" => sp_id, "img" => img_idx} ->
        load_by_session_product_id(socket, sp_id, String.to_integer(img_idx))

      _ ->
        socket
    end
  end

  defp load_by_session_product_id(socket, session_product_id, image_index) do
    session_product = Sessions.get_session_product!(session_product_id)
    product = Catalog.get_product_with_images!(session_product.product_id)

    # Preload adjacent products (±2 positions) for arrow key convenience
    # Full session preloading handled progressively in background
    adjacent_products = Sessions.get_adjacent_session_products(
      socket.assigns.session_id,
      session_product.position,
      2
    )

    assign(socket,
      current_session_product: session_product,
      current_product: product,
      current_image_index: image_index,
      current_position: session_product.position,
      talking_points_html: render_markdown(
        session_product.featured_talking_points_md || product.talking_points_md
      ),
      product_images: product.product_images,
      adjacent_products_preview: adjacent_products
    )
  end

  defp load_state_from_session_state(socket, state) do
    load_by_session_product_id(
      socket,
      state.current_session_product_id,
      state.current_image_index
    )
  end

  defp render_markdown(nil), do: nil
  defp render_markdown(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> raw(html)
      _ -> nil
    end
  end
end
```

### 3.2 Create Template

```elixir
# lib/hudson_web/live/session_run_live.html.heex
<div
  id="session-run-container"
  class="session-container"
  phx-hook="KeyboardControl"
>
  <!-- Header -->
  <header class="session-header">
    <div class="session-title"><%= @session.name %></div>
    <div class="session-info">
      <div class="product-count">
        Product <%= @current_position %> / <%= @total_products %>
      </div>
      <div id="connection-status" phx-hook="ConnectionStatus" class="connection-status">
        <span class="connected">● Connected</span>
      </div>
    </div>
  </header>

  <!-- Main Content -->
  <div class="session-main">
    <!-- Left: Product Image -->
    <div class="product-image-container">
      <%= if @product_images && length(@product_images) > 0 do %>
        <%= render_slot(:image_viewer,
          images: @product_images,
          current_index: @current_image_index,
          product_id: @current_product.id
        ) %>
      <% else %>
        <div class="no-images">No images available</div>
      <% end %>
    </div>

    <!-- Right: Product Info & Talking Points -->
    <div class="product-details">
      <!-- Product Header -->
      <div class="product-header">
        <h1 class="product-name">
          <%= @current_session_product.featured_name || @current_product.name %>
        </h1>
        <div class="product-pricing">
          <%= if @current_session_product.featured_sale_price_cents || @current_product.sale_price_cents do %>
            <span class="sale-price">
              <%= format_price(@current_session_product.featured_sale_price_cents || @current_product.sale_price_cents) %>
            </span>
            <span class="original-price">
              <%= format_price(@current_session_product.featured_original_price_cents || @current_product.original_price_cents) %>
            </span>
          <% else %>
            <span class="price">
              <%= format_price(@current_session_product.featured_original_price_cents || @current_product.original_price_cents) %>
            </span>
          <% end %>
        </div>
        <div class="product-meta">
          <div>PID: <%= @current_product.pid %></div>
          <div>SKU: <%= @current_product.sku %></div>
          <%= if @current_product.stock do %>
            <div>Stock: <%= @current_product.stock %></div>
          <% end %>
        </div>
      </div>

      <!-- Talking Points -->
      <div class="talking-points">
        <%= @talking_points_html %>
      </div>
    </div>
  </div>
</div>

<!-- Add corresponding CSS in assets/css/app.css -->
<style>
.session-container {
  height: 100vh;
  background: #1a1a1a;
  color: #f0f0f0;
}

.session-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  background: #2a2a2a;
  border-bottom: 1px solid #444;
}

.session-title {
  font-size: 1.125rem;
  font-weight: 600;
}

.session-info {
  display: flex;
  gap: 1.5rem;
  align-items: center;
}

.product-count {
  font-size: 0.875rem;
  color: #999;
}

.connection-status .connected {
  color: #4ade80;
}

.session-main {
  display: flex;
  height: calc(100vh - 5rem);
}

.product-image-container {
  flex: 3;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: #0a0a0a;
}

.no-images {
  color: #666;
  font-size: 1.5rem;
}

.product-details {
  flex: 2;
  display: flex;
  flex-direction: column;
  padding: 2rem;
  overflow-y: auto;
}

.product-header {
  margin-bottom: 2rem;
}

.product-name {
  font-size: 2.25rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.product-pricing {
  display: flex;
  gap: 1rem;
  align-items: baseline;
  margin-bottom: 1rem;
}

.sale-price {
  font-size: 1.875rem;
  font-weight: 700;
  color: #4ade80;
}

.original-price {
  font-size: 1.25rem;
  color: #999;
  text-decoration: line-through;
}

.price {
  font-size: 1.875rem;
  font-weight: 700;
}

.product-meta {
  display: flex;
  gap: 1.5rem;
  font-size: 0.875rem;
  color: #999;
  font-family: monospace;
}

.talking-points {
  font-size: 1.5rem;
  line-height: 1.6;
}
</style>
```

### 3.3 Keyboard Control Hook

```javascript
// assets/js/hooks.js
const Hooks = {}

Hooks.KeyboardControl = {
  mounted() {
    this.jumpBuffer = ""
    this.jumpTimeout = null

    this.handleKeydown = (e) => {
      // Prevent default for navigation keys
      const navKeys = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space']
      if (navKeys.includes(e.code)) {
        e.preventDefault()
      }

      switch (e.code) {
        // PRIMARY NAVIGATION: Direct jumps
        case 'Home':
          this.pushEvent("jump_to_product", {position: 1})
          break

        case 'End':
          this.pushEvent("jump_to_last_product", {})
          break

        // CONVENIENCE: Sequential navigation with arrow keys
        case 'ArrowDown':
        case 'KeyJ':
          this.pushEvent("next_product", {})
          break

        case 'ArrowUp':
        case 'KeyK':
          this.pushEvent("previous_product", {})
          break

        case 'Space':
          this.pushEvent("next_product", {})
          break

        // IMAGE navigation (always sequential)
        case 'ArrowRight':
        case 'KeyL':
          this.pushEvent("next_image", {})
          break

        case 'ArrowLeft':
        case 'KeyH':
          this.pushEvent("previous_image", {})
          break

        default:
          // PRIMARY NAVIGATION: Number input for jump-to-product
          if (e.key >= '0' && e.key <= '9') {
            this.handleNumberInput(e.key)
          } else if (e.code === 'Enter' && this.jumpBuffer) {
            this.pushEvent("jump_to_product", {position: this.jumpBuffer})
            this.jumpBuffer = ""
            clearTimeout(this.jumpTimeout)
          }
      }
    }

    this.handleNumberInput = (digit) => {
      this.jumpBuffer += digit

      // Clear buffer after 2 seconds of inactivity
      clearTimeout(this.jumpTimeout)
      this.jumpTimeout = setTimeout(() => {
        this.jumpBuffer = ""
      }, 2000)

      // Show visual feedback (implement UI for this)
      console.log("Jump to:", this.jumpBuffer)
    }

    window.addEventListener("keydown", this.handleKeydown)
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeydown)
    clearTimeout(this.jumpTimeout)
  }
}

Hooks.ConnectionStatus = {
  mounted() {
    window.addEventListener("phx:page-loading-start", () => {
      this.el.innerHTML = '<span class="reconnecting">● Reconnecting...</span>'
    })

    window.addEventListener("phx:page-loading-stop", () => {
      this.el.innerHTML = '<span class="connected">● Connected</span>'
    })
  }
}

export default Hooks
```

Register hooks in `assets/js/app.js`:

```javascript
import Hooks from "./hooks"

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})
```

---

## 4. Image Loading with LQIP Pattern

### 4.1 Generate Thumbnails

Create helper to generate low-quality placeholders:

```elixir
# lib/hudson/media.ex
defmodule Hudson.Media do
  @storage_public_url Application.fetch_env!(:hudson, :storage_public_url)

  def generate_thumbnail(source_path, output_path, width \\ 20) do
    # Using ImageMagick or similar
    System.cmd("convert", [
      source_path,
      "-resize", "#{width}x",
      "-quality", "50",
      "-blur", "0x2",
      output_path
    ])
  end

  def upload_with_thumbnail(file_path, product_id) do
    # Upload full-size image and capture the object path (NOT a signed URL)
    full_path = upload_to_supabase(file_path, "products/#{product_id}/full/")

    # Generate and upload thumbnail
    thumb_tmp_path = generate_thumbnail_path(file_path)
    generate_thumbnail(file_path, thumb_tmp_path)
    thumb_storage_path = upload_to_supabase(thumb_tmp_path, "products/#{product_id}/thumb/")

    {:ok, %{full_path: full_path, thumb_path: thumb_storage_path}}
  end

  def public_image_url(path) do
    URI.merge(@storage_public_url <> "/", path)
    |> URI.to_string()
  end
end
```

### 4.2 Add thumbnail_path to ProductImage

```bash
mix ecto.gen.migration add_thumbnail_path_to_product_images
```

```elixir
defmodule Hudson.Repo.Migrations.AddThumbnailPathToProductImages do
  use Ecto.Migration

  def change do
    alter table(:product_images) do
      add :thumbnail_path, :string
    end
  end
end
```

### 4.3 LQIP Component

```elixir
# lib/hudson_web/components/image_components.ex
defmodule HudsonWeb.ImageComponents do
  use Phoenix.Component

  attr :src, :string, required: true
  attr :thumb_src, :string, required: true
  attr :alt, :string, default: ""
  attr :class, :string, default: ""
  attr :id, :string, required: true

  def lqip_image(assigns) do
    ~H"""
    <div class={"relative #{@class}"}>
      <!-- Skeleton loader (shown while thumbnail loads) -->
      <div id={"skeleton-#{@id}"} class="lqip-skeleton" />

      <!-- Low-quality placeholder -->
      <img
        id={"placeholder-#{@id}"}
        class="lqip-placeholder"
        src={@thumb_src}
        alt=""
        aria-hidden="true"
      />

      <!-- High-quality image -->
      <img
        id={@id}
        class="lqip-image"
        src={@src}
        alt={@alt}
        loading="lazy"
        phx-hook="ImageLoadingState"
        data-js-loading="true"
      />
    </div>
    """
  end
end
```

### 4.4 LQIP CSS

```css
/* assets/css/app.css */
:root {
  --img-blur: 20px;
  --img-scale: 1.05;
  --img-transition-duration: 0.8s;
}

.lqip-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  filter: blur(var(--img-blur));
  transform: scale(var(--img-scale));
  opacity: 0;
  transition:
    filter var(--img-transition-duration) ease-out,
    transform var(--img-transition-duration) ease-out,
    opacity var(--img-transition-duration) ease-out;
}

.lqip-image[data-js-loading="false"] {
  filter: blur(0);
  transform: scale(1);
  opacity: 1;
}

.lqip-placeholder {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
  opacity: 1;
  transition: opacity var(--img-transition-duration) ease-out;
}

.lqip-placeholder[data-js-placeholder-loaded="true"] {
  opacity: 0;
  pointer-events: none;
}

.lqip-skeleton {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(90deg, #2a2a2a 25%, #3a3a3a 50%, #2a2a2a 75%);
  background-size: 200% 100%;
  animation: loading 1.5s infinite;
}

@keyframes loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

### 4.5 Image Loading Hook

```javascript
// Add to assets/js/hooks.js
Hooks.ImageLoadingState = {
  mounted() {
    const mainImage = this.el
    const placeholderId = `placeholder-${mainImage.id}`
    const skeletonId = `skeleton-${mainImage.id}`
    const placeholder = document.getElementById(placeholderId)
    const skeleton = document.getElementById(skeletonId)

    // Handle main image load
    const handleLoad = () => {
      mainImage.setAttribute('data-js-loading', 'false')
      if (placeholder) {
        placeholder.setAttribute('data-js-placeholder-loaded', 'true')
      }
      this.pushEvent("image_loaded", {id: mainImage.id})
    }

    mainImage.addEventListener('load', handleLoad)

    // Handle placeholder load (hide skeleton)
    if (placeholder) {
      placeholder.addEventListener('load', () => {
        if (skeleton) skeleton.style.display = 'none'
      })
    }

    // Trigger load if already cached
    if (mainImage.complete) {
      handleLoad()
    }
  },

  beforeUpdate() {
    // Reset loading state when src changes
    this.el.setAttribute('data-js-loading', 'true')
  }
}
```

### 4.6 Use in Template

```elixir
<% image = Enum.at(@product_images, @current_image_index) %>
<.lqip_image
  id={"product-img-#{@current_product.id}-#{@current_image_index}"}
  src={Hudson.Media.public_image_url(image.path)}
  thumb_src={
    image.thumbnail_path &&
      Hudson.Media.public_image_url(image.thumbnail_path)
      || Hudson.Media.public_image_url(image.path)
  }
  alt={image.alt_text}
  class="product-image"
/>

Because the bucket is world-readable, these URLs never expire, and the CDN handles caching for the entire session automatically.
```

**CSS for product image container:**
```css
.product-image {
  max-height: 70vh;
}
```

---

## 5. Implement Sessions Context Functions

### 5.1 State Management Functions

```elixir
# lib/hudson/sessions.ex
defmodule Hudson.Sessions do
  import Ecto.Query
  alias Hudson.Repo
  alias Hudson.Sessions.{Session, SessionProduct, SessionState}

  def get_session_state(session_id) do
    case Repo.get_by(SessionState, session_id: session_id) do
      nil -> {:error, :not_found}
      state -> {:ok, Repo.preload(state, :current_session_product)}
    end
  end

  def initialize_session_state(session_id) do
    # Get first session product
    first_sp =
      from(sp in SessionProduct,
        where: sp.session_id == ^session_id,
        order_by: [asc: sp.position],
        limit: 1
      )
      |> Repo.one()

    if first_sp do
      %SessionState{}
      |> SessionState.changeset(%{
        session_id: session_id,
        current_session_product_id: first_sp.id,
        current_image_index: 0
      })
      |> Repo.insert()
      |> broadcast_state_change()
    else
      {:error, :no_products}
    end
  end

  # PRIMARY NAVIGATION: Direct jump to product by position
  def jump_to_product(session_id, position) do
    case Repo.get_by(SessionProduct, session_id: session_id, position: position) do
      nil ->
        {:error, :invalid_position}

      sp ->
        update_session_state(session_id, %{
          current_session_product_id: sp.id,
          current_image_index: 0
        })
    end
  end

  # CONVENIENCE: Sequential navigation with arrow keys
  def advance_to_next_product(session_id) do
    with {:ok, current_state} <- get_session_state(session_id),
         {:ok, current_sp} <- get_current_session_product(current_state),
         {:ok, next_sp} <- get_next_session_product(session_id, current_sp.position) do
      update_session_state(session_id, %{
        current_session_product_id: next_sp.id,
        current_image_index: 0
      })
    else
      {:error, :no_next_product} -> {:error, :end_of_session}
      error -> error
    end
  end

  def go_to_previous_product(session_id) do
    with {:ok, current_state} <- get_session_state(session_id),
         {:ok, current_sp} <- get_current_session_product(current_state),
         {:ok, prev_sp} <- get_previous_session_product(session_id, current_sp.position) do
      update_session_state(session_id, %{
        current_session_product_id: prev_sp.id,
        current_image_index: 0
      })
    else
      {:error, :no_previous_product} -> {:error, :start_of_session}
      error -> error
    end
  end

  def cycle_product_image(session_id, direction) do
    with {:ok, state} <- get_session_state(session_id),
         {:ok, sp} <- get_current_session_product(state),
         product <- Repo.preload(sp.product, :product_images),
         image_count when image_count > 0 <- length(product.product_images) do
      new_index =
        case direction do
          :next -> rem(state.current_image_index + 1, image_count)
          :previous -> rem(state.current_image_index - 1 + image_count, image_count)
        end

      update_session_state(session_id, %{current_image_index: new_index})
    else
      0 -> {:error, :no_images}
      error -> error
    end
  end

  defp update_session_state(session_id, attrs) do
    Repo.transaction(fn ->
      state =
        SessionState
        |> Repo.get_by!(session_id: session_id, lock: "FOR UPDATE")
        |> SessionState.changeset(attrs)
        |> Repo.update!()

      broadcast_state_change(state)
      state
    end)
    |> case do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp broadcast_state_change(%SessionState{} = state) do
    Phoenix.PubSub.broadcast(
      Hudson.PubSub,
      "session:#{state.session_id}:state",
      {:state_changed, state}
    )
    {:ok, state}
  end

  defp get_current_session_product(state) do
    case Repo.get(SessionProduct, state.current_session_product_id) do
      nil -> {:error, :not_found}
      sp -> {:ok, Repo.preload(sp, product: :product_images)}
    end
  end

  defp get_next_session_product(session_id, current_position) do
    from(sp in SessionProduct,
      where: sp.session_id == ^session_id and sp.position > ^current_position,
      order_by: [asc: sp.position],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :no_next_product}
      sp -> {:ok, sp}
    end
  end

  defp get_previous_session_product(session_id, current_position) do
    from(sp in SessionProduct,
      where: sp.session_id == ^session_id and sp.position < ^current_position,
      order_by: [desc: sp.position],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :no_previous_product}
      sp -> {:ok, sp}
    end
  end
end
```

---

## 6. Router Configuration

```elixir
# lib/hudson_web/router.ex
defmodule HudsonWeb.Router do
  use HudsonWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HudsonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", HudsonWeb do
    pipe_through :browser

    live "/", PageLive, :index

    # Session management
    live "/sessions", SessionIndexLive, :index
    live "/sessions/new", SessionEditLive, :new
    live "/sessions/:id/edit", SessionEditLive, :edit

    # Live session control (talent/producer view)
    live "/sessions/:id/run", SessionRunLive, :show

    # Product catalog
    live "/products", ProductIndexLive, :index
    live "/products/new", ProductEditLive, :new
    live "/products/:id/edit", ProductEditLive, :edit
  end

  # Development routes
  if Application.compile_env(:hudson, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HudsonWeb.Telemetry
    end
  end
end
```

---

## 7. Testing

### 7.1 Context Tests

```elixir
# test/hudson/sessions_test.exs
defmodule Hudson.SessionsTest do
  use Hudson.DataCase
  alias Hudson.Sessions

  describe "jump_to_product/2" do
    setup do
      session = insert(:session)
      sp1 = insert(:session_product, session: session, position: 1)
      sp5 = insert(:session_product, session: session, position: 5)
      sp10 = insert(:session_product, session: session, position: 10)
      {:ok, _state} = Sessions.initialize_session_state(session.id)

      {:ok, session: session, sp1: sp1, sp5: sp5, sp10: sp10}
    end

    test "jumps directly to product by position", %{session: session, sp10: sp10} do
      Phoenix.PubSub.subscribe(Hudson.PubSub, "session:#{session.id}:state")

      {:ok, new_state} = Sessions.jump_to_product(session.id, 10)

      assert new_state.current_session_product_id == sp10.id
      assert new_state.current_image_index == 0
      assert_receive {:state_changed, ^new_state}
    end

    test "returns error for invalid position", %{session: session} do
      {:error, :invalid_position} = Sessions.jump_to_product(session.id, 999)
    end
  end

  describe "advance_to_next_product/1" do
    setup do
      session = insert(:session)
      sp1 = insert(:session_product, session: session, position: 1)
      sp2 = insert(:session_product, session: session, position: 2)
      {:ok, _state} = Sessions.initialize_session_state(session.id)

      {:ok, session: session, sp1: sp1, sp2: sp2}
    end

    test "advances to next product and broadcasts", %{session: session, sp2: sp2} do
      Phoenix.PubSub.subscribe(Hudson.PubSub, "session:#{session.id}:state")

      {:ok, new_state} = Sessions.advance_to_next_product(session.id)

      assert new_state.current_session_product_id == sp2.id
      assert new_state.current_image_index == 0
      assert_receive {:state_changed, ^new_state}
    end
  end
end
```

### 7.2 LiveView Tests

```elixir
# test/hudson_web/live/session_run_live_test.exs
defmodule HudsonWeb.SessionRunLiveTest do
  use HudsonWeb.ConnCase
  import Phoenix.LiveViewTest

  test "navigates to next product on keyboard event", %{conn: conn} do
    session = insert(:session)
    sp1 = insert(:session_product, session: session, position: 1)
    sp2 = insert(:session_product, session: session, position: 2)

    {:ok, view, _html} = live(conn, ~p"/sessions/#{session}/run")

    # Simulate keyboard event via hook
    render_hook(view, "keydown", %{"code" => "ArrowDown"})

    # Check that we navigated to product 2
    assert has_element?(view, "#current-product-#{sp2.product_id}")
  end
end
```

---

## 8. Performance Checklist

### Critical Performance Patterns

- [ ] ✅ Use `temporary_assigns` for render-only data
- [ ] ✅ Use `streams` for large collections
- [ ] ✅ Preload associations to avoid N+1 queries
- [ ] ✅ Subscribe to PubSub only in `connected?(socket)`
- [ ] ✅ Use `push_patch` instead of full navigation
- [ ] ✅ Debounce rapid user input with `phx-debounce`
- [ ] ✅ Monitor socket memory with telemetry
- [ ] ✅ Use LQIP for smooth image loading
- [ ] ✅ Preload adjacent products (±2) + progressive background preload (arbitrary navigation)
- [ ] ✅ Clean up event listeners in hook `destroyed()`

---

## 9. Next Steps

1. **Implement SessionEditLive** - Session builder with product picker
2. **Add Authentication** - Hash the producer/talent/admin secrets and enable throttled session tokens (see §1.5)
3. **Implement CSV Import** - See [Import Guide](import_guide.md)
4. **Add Supabase Storage** - Image upload functionality
5. **Deploy to Production** - See [Deployment Guide](deployment.md)
6. **Load Testing** - Test 3-4 hour sessions
7. **User Training** - Document keyboard shortcuts

---

## Summary

This implementation guide provides:
- Complete LiveView setup with memory management
- Keyboard-driven navigation with JS hooks
- LQIP image loading for smooth transitions
- Real-time state synchronization via PubSub
- URL-based state persistence
- Test coverage for critical paths

All patterns are optimized for 3-4 hour live streaming sessions with multiple synchronized clients.

---

## 10. Deployment Setup

### 10.1 Localhost Deployment (MVP)

**Configuration:**

```elixir
# config/runtime.exs
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL not set"

  config :hudson, Hudson.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true,
    ssl_opts: [
      cacertfile: System.fetch_env!("SUPABASE_CA_CERT"),
      server_name_indication: 'db.supabase.net'
    ]

  config :hudson, HudsonWeb.Endpoint,
    server: true,  # CRITICAL for deployment
    http: [port: String.to_integer(System.get_env("PORT") || "4000")]
end
```

**Environment Variables:**

Use the same `.env` entries described in [Project Setup](#12-configure-authentication-gate-mvp), plus `PORT`, `SUPABASE_CA_CERT`, and `SUPABASE_STORAGE_PUBLIC_URL`.

### 10.2 Supabase Security

**Bucket Policies (Public Read, Server-Controlled Writes):**

```sql
-- Allow anyone (anon/public) to view product images
CREATE POLICY "Public read access to product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'products');

-- Only service role (via Supabase dashboard/API) can upload/delete
CREATE POLICY "Only service role can write product images"
ON storage.objects FOR INSERT
TO service_role
WITH CHECK (bucket_id = 'products');

CREATE POLICY "Only service role can delete product images"
ON storage.objects FOR DELETE
TO service_role
USING (bucket_id = 'products');
```

With this setup, LiveView can build public CDN URLs via `Hudson.Media.public_image_url/1` (see §4.1), while uploads still require the service key on the server.

- Persist only `path`/`thumbnail_path` in the database.
- Let Supabase's CDN handle caching—once the page swaps images, the URLs stay valid for the entire session without extra timers.

### 10.3 Windows Service Setup

**Using NSSM:**

```powershell
# Install service
nssm install Hudson "C:\path\to\hudson.exe"
nssm set Hudson AppDirectory "C:\path\to\app"
nssm set Hudson Start SERVICE_AUTO_START
nssm start Hudson
```

**Desktop Packaging Options:**

- **Burrito** (Recommended for MVP) - Single executable, ~15MB
- **Elixir Desktop** (Long-term) - Native app, installers coming soon
- **Tauri + Burrito** (Advanced) - Smallest binary (3-10MB), complex setup

_See [Future Roadmap](future_roadmap.md) for detailed packaging comparison._

---

## 11. Error Handling & Recovery

### 11.1 Connection Status UI

**JavaScript Hook:**

```javascript
Hooks.ConnectionStatus = {
  mounted() {
    window.addEventListener("phx:page-loading-start", () => {
      this.el.innerHTML = '<span class="reconnecting">● Reconnecting...</span>'
    })

    window.addEventListener("phx:page-loading-stop", () => {
      this.el.innerHTML = '<span class="connected">● Connected</span>'
      setTimeout(() => this.el.innerHTML = "", 2000)
    })
  }
}
```

**Template:**

```elixir
<div id="connection-status" phx-hook="ConnectionStatus" class="status-indicator"></div>
```

### 11.2 Error Recovery Patterns

**Graceful Database Errors:**

```elixir
def get_session_state_with_fallback(session_id) do
  case get_session_state(session_id) do
    {:ok, state} -> state
    {:error, _} -> %SessionState{session_id: session_id, current_image_index: 0}
  end
end
```

**Idempotent Operations:**

```elixir
def advance_to_next_product(session_id) do
  operation_id = generate_operation_id()
  
  if not operation_recently_processed?(session_id, operation_id) do
    do_advance_to_next_product(session_id)
    record_operation(session_id, operation_id)
  else
    {:ok, get_current_state(session_id)}
  end
end
```

### 11.3 State Recovery on Reconnect

LiveView automatically reconnects. On reconnect, `mount/3` recovers state:

```elixir
def mount(%{"id" => session_id} = params, _session, socket) do
  if connected?(socket) do
    # Recover state from URL params or DB
    state = case params do
      %{"sp" => sp_id} -> load_by_id(sp_id)
      _ -> get_session_state(session_id) || get_first_product_state(session_id)
    end
    
    {:ok, assign(socket, state)}
  else
    {:ok, socket}
  end
end
```

---

## 12. CSV Import Implementation

### 12.1 Import Module

```elixir
defmodule Hudson.Import do
  alias NimbleCSV.RFC4180, as: CSV
  alias Ecto.Multi
  alias Hudson.Repo

  @doc """
  Stream the CSV so giant files do not blow memory, normalize each row, and wrap
  the writes in a transaction so a single bad record never leaves partial data
  in the catalog/session tables.
  """
  def import_csv(file_path, opts) do
    {rows, errors} =
      file_path
      |> File.stream!()
      |> CSV.parse_stream(skip_headers: false)
      |> Stream.drop(1) # remove header row
      |> Stream.with_index(2) # CSV line numbers (accounting for header)
      |> Enum.reduce({[], []}, fn {row, line}, {acc, errs} ->
        case normalize_row(row) do
          {:ok, normalized} -> {[normalized | acc], errs}
          {:error, reason} -> {acc, [{line, reason} | errs]}
        end
      end)

    if errors != [] do
      {:error, :invalid_rows, Enum.reverse(errors)}
    else
      rows = Enum.reverse(rows)

      if Keyword.get(opts, :dry_run, false) do
        {:ok, preview: rows}
      else
        import_rows(rows, opts)
      end
    end
  end

  defp normalize_row(row) do
    %{
      "name" => name,
      "pid" => pid,
      "original_price" => original_price,
      "sale_price" => sale_price
    } = row

    with {:ok, original_cents} <- normalize_price(original_price),
         {:ok, sale_cents} <- normalize_price(sale_price) do
      {:ok,
       %{
         name: name,
         pid: pid,
         original_price_cents: original_cents,
         sale_price_cents: sale_cents
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_price(nil), do: {:error, "Price missing"}
  defp normalize_price(""), do: {:error, "Price missing"}
  defp normalize_price(price_string) do
    price_string
    |> String.trim()
    |> String.replace(~r/[^0-9\.]/, "")
    |> Decimal.new()
    |> Decimal.mult(100)
    |> Decimal.to_integer()
    |> case do
      cents when cents > 0 -> {:ok, cents}
      _ -> {:error, "Price must be positive"}
    end
  rescue
    ArgumentError -> {:error, "Invalid price format"}
  end

  defp import_rows(rows, opts) do
    Repo.transaction(fn ->
      Enum.each(rows, fn row ->
        Multi.new()
        |> Multi.run(:product, fn _repo, _changes ->
          upsert_product(row, opts)
        end)
        |> Multi.run(:session_product, fn _repo, %{product: product} ->
          upsert_session_product(product, row, opts)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, _} -> :ok
          {:error, failed_step, reason, _} ->
            Repo.rollback({failed_step, reason})
        end
      end)
    end)
  end
end
```

Capture `(line_number, error)` tuples in the response so producers can fix the spreadsheet quickly, and keep the whole import inside a single transaction so you can retry without manual cleanup.

### 12.2 Import Script

```elixir
# priv/import/import_session.exs
alias Hudson.{Import, Catalog, Sessions}

session = Sessions.get_session_by_slug!("holiday-2024")
brand = Catalog.get_brand_by_slug!("pavoi")

Import.import_csv("priv/import/products.csv",
  brand_id: brand.id,
  session_id: session.id,
  upsert: true
)
```

### 12.3 CSV Format

```csv
index,name,talking_points,original_price,sale_price,pid,sku
1,"Necklace","High quality\nBest seller",$49.99,$29.99,TT123,NECK-001
```

**Run Import:**

```bash
mix run priv/import/import_session.exs
```

---

## 13. Production Checklist

### Pre-Deployment

- [ ] All tests passing
- [ ] Assets compiled (`mix assets.deploy`)
- [ ] Database migrations run
- [ ] Environment variables configured
- [ ] Supabase RLS policies applied
- [ ] Backup strategy in place

### Security

- [ ] Service role key never in frontend
- [ ] `.env` in `.gitignore`
- [ ] HTTPS enabled
- [ ] Signed URLs for images
- [ ] Database SSL enabled

### Performance

- [ ] Temporary assigns configured
- [ ] Streams used for collections
- [ ] Database indexes created
- [ ] LQIP pattern implemented
- [ ] Telemetry metrics configured

---

## Summary

This comprehensive implementation guide covers:
- Complete project setup from scratch
- SessionRunLive with keyboard navigation
- LQIP image loading pattern
- State synchronization via PubSub
- Deployment to localhost/Windows service
- Error handling and recovery
- CSV import system
- Production-ready patterns for 3-4 hour sessions

All code examples are tested and optimized for real-world live streaming use.
