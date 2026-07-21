# ii-desktop-mcp - Desktop Intelligence MCP Server
# Enables the systemd user service that provides structured desktop tools
# via Model Context Protocol for AI clients (Quickshell sidebar, Kiro, etc.)
{ ... }:
{
  services.ii-desktop-mcp.enable = true;
}
