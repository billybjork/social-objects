defmodule SocialObjectsWeb.Plugs.CSPNonce do
  @moduledoc """
  Plug that generates a CSP nonce for inline scripts and sets the Content-Security-Policy header.

  This allows specific inline scripts (marked with the nonce) to execute while maintaining
  strong CSP protection against XSS attacks.

  Usage:
    plug SocialObjectsWeb.Plugs.CSPNonce, csp_config: :strict

  In templates, use the nonce:
    <script nonce={@csp_nonce}>...</script>
  """

  import Plug.Conn

  @strict_csp_base "default-src 'self'; " <>
                     "script-src 'self' blob: data: 'nonce-{{NONCE}}'; " <>
                     "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
                     "style-src-elem 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
                     "img-src 'self' data: blob: https:; " <>
                     "font-src 'self' data: https://cdnjs.cloudflare.com; " <>
                     "frame-src 'self' blob: data: https://www.tiktok.com; " <>
                     "child-src 'self' blob: data:; " <>
                     "connect-src 'self' ws: wss: https://storage.railway.app; " <>
                     "frame-ancestors 'self'; " <>
                     "base-uri 'self';"

  @editor_csp_base "default-src 'self'; " <>
                     "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: data:; " <>
                     "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
                     "style-src-elem 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
                     "img-src 'self' data: blob: https:; " <>
                     "font-src 'self' data: https://cdnjs.cloudflare.com; " <>
                     "frame-src 'self' blob: data: https://www.tiktok.com; " <>
                     "child-src 'self' blob: data:; " <>
                     "connect-src 'self' ws: wss: https://storage.railway.app; " <>
                     "frame-ancestors 'self'; " <>
                     "base-uri 'self';"

  def init(opts), do: opts

  def call(conn, opts) do
    nonce = generate_nonce()
    csp_config = Keyword.get(opts, :csp_config, :strict)

    csp_header = build_csp_header(csp_config, nonce)

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", csp_header)
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp build_csp_header(:strict, nonce) do
    String.replace(@strict_csp_base, "{{NONCE}}", nonce)
  end

  defp build_csp_header(:editor, _nonce) do
    # Editor CSP already has unsafe-inline, no need for nonce
    @editor_csp_base
  end
end
