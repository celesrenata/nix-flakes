# Model Context Protocol (MCP) Servers

This directory contains MCP server implementations that extend AI assistants (Kiro CLI, Amazon Q) with additional capabilities.

## Servers

### openai-dalle
DALL-E image generation via OpenAI API. Allows AI assistants to generate images from text descriptions.

**Requirements:**
- OpenAI API key stored in sops secrets at `/run/secrets/openai_api_token`

**Tools provided:**
- `generate_image` - Generate images from text prompts
- `create_variation` - Create variations of existing images

### mcp-chatgpt-responses
ChatGPT conversation API. Enables AI assistants to have conversations with ChatGPT models.

**Requirements:**
- OpenAI API key stored in sops secrets at `/run/secrets/openai_api_token`

**Tools provided:**
- `ask_chatgpt` - Send prompts to ChatGPT and get responses
- `ask_chatgpt_with_web_search` - ChatGPT with web search capability

### browser (external)
Browser automation via Playwright. Located at `~/mcp-browser-server/`.

**Tools provided:**
- `browser_navigate` - Navigate to URLs and test accessibility
- `browser_screenshot` - Take screenshots of webpages
- `browser_test_dashboard` - Test Noctipede dashboards

## Configuration

MCP servers are configured via `home/programs/mcp.nix` and deployed to:
- Amazon Q: `~/.aws/amazonq/mcp.json`
- Kiro CLI: `~/.kiro/settings/mcp.json`

Server files are deployed to `~/ai/mcp/` with nix-shell environments for dependency management.

## Architecture

Each MCP server:
1. Communicates via JSON-RPC on stdout
2. Uses nix-shell for isolated Python environments
3. Redirects all non-JSON output to stderr
4. Reads OpenAI API key from sops secrets at runtime

## Adding New Servers

1. Add server source files to `mcp/<server-name>/`
2. Update `home/programs/mcp.nix` with:
   - Server configuration in `mcpConfig.mcpServers`
   - File deployments for source files
   - Shell.nix if needed
3. Rebuild with `sudo nixos-rebuild switch`
