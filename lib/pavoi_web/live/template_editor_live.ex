defmodule PavoiWeb.TemplateEditorLive do
  @moduledoc """
  Full-page LiveView for editing email templates with GrapesJS.

  Routes:
  - /templates/new     - Create new template
  - /templates/:id/edit - Edit existing template
  """
  use PavoiWeb, :live_view

  on_mount {PavoiWeb.NavHooks, :set_current_page}

  alias Pavoi.Communications
  alias Pavoi.Communications.EmailTemplate

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    template = %EmailTemplate{lark_preset: "jewelry"}
    changeset = Communications.change_email_template(template)

    socket
    |> assign(:page_title, "New Template")
    |> assign(:template, template)
    |> assign(:form, to_form(changeset))
    |> assign(:is_new, true)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    template = Communications.get_email_template!(id)
    changeset = Communications.change_email_template(template)

    socket
    |> assign(:page_title, "Edit Template")
    |> assign(:template, template)
    |> assign(:form, to_form(changeset))
    |> assign(:is_new, false)
  end

  @impl true
  def handle_event("validate", %{"email_template" => params}, socket) do
    changeset =
      socket.assigns.template
      |> Communications.change_email_template(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("template_html_updated", %{"html" => html}, socket)
      when is_binary(html) and html != "" do
    # Update the form with the HTML from the visual editor
    current_params = %{
      "name" => socket.assigns.form[:name].value || "",
      "subject" => socket.assigns.form[:subject].value || "",
      "lark_preset" => socket.assigns.form[:lark_preset].value || "jewelry",
      "html_body" => html
    }

    changeset = Communications.change_email_template(socket.assigns.template, current_params)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Ignore empty or missing HTML updates (happens during editor initialization)
  def handle_event("template_html_updated", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"email_template" => params}, socket) do
    result =
      if socket.assigns.is_new do
        Communications.create_email_template(params)
      else
        Communications.update_email_template(socket.assigns.template, params)
      end

    case result do
      {:ok, _template} ->
        socket =
          socket
          |> put_flash(:info, "Template saved successfully")
          |> push_navigate(to: ~p"/creators?pt=templates")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
