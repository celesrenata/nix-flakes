# ii-desktop-mcp - Desktop Intelligence MCP Server
# Enables the systemd user service that provides structured desktop tools
# via Model Context Protocol for AI clients (Quickshell sidebar, Kiro, etc.)
{ pkgs, lib, ... }:
{
  services.ii-desktop-mcp.enable = true;

  # Override ExecStart to use our overlayed package (has patched Hyprland)
  systemd.user.services.ii-desktop-mcp.Service.ExecStart = lib.mkForce
    "${pkgs.ii-desktop-mcp}/bin/ii-desktop-mcp";
}
