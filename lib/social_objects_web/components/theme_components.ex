defmodule SocialObjectsWeb.ThemeComponents do
  @moduledoc """
  Reusable components for theme management (light/dark mode).
  """
  use Phoenix.Component

  @doc """
  Renders a theme toggle button that switches between light and dark modes.

  The button uses the ThemeToggle JavaScript hook to manage state and persistence.
  Icons are shown/hidden based on the current theme via CSS.

  ## Example

      <.theme_toggle />
  """
  attr :class, :string, default: nil, doc: "Additional CSS classes"

  def theme_toggle(assigns) do
    ~H"""
    <button
      phx-hook="ThemeToggle"
      id="theme-toggle"
      class={["theme-toggle", @class]}
      aria-label="Toggle light/dark mode"
      title="Toggle theme"
      type="button"
    >
      <span class="theme-toggle__icon theme-toggle__icon--sun" aria-hidden="true">☼</span>
      <span class="theme-toggle__icon theme-toggle__icon--moon" aria-hidden="true">☾</span>
      <span class="sr-only">Toggle theme</span>
    </button>
    """
  end

  @doc """
  Renders an iOS-style toggle switch for theme selection.

  Uses the same ThemeToggle JavaScript hook but displays as a sliding switch
  with sun/moon icons on each side.

  ## Example

      <.theme_switch />
  """
  attr :class, :string, default: nil, doc: "Additional CSS classes"

  def theme_switch(assigns) do
    ~H"""
    <button
      phx-hook="ThemeToggle"
      id="theme-toggle"
      class={["theme-switch", @class]}
      aria-label="Toggle light/dark mode"
      role="switch"
      aria-checked="false"
      type="button"
    >
      <span class="theme-switch__icon theme-switch__icon--sun" aria-hidden="true">☼</span>
      <span class="theme-switch__track">
        <span class="theme-switch__thumb"></span>
      </span>
      <span class="theme-switch__icon theme-switch__icon--moon" aria-hidden="true">☾</span>
      <span class="sr-only">Toggle theme</span>
    </button>
    """
  end
end
