# Model Context Protocol (MCP) Servers Configuration
# Provides AI assistants (Kiro CLI, Amazon Q) with additional capabilities
# through standardized MCP servers for browser automation, image generation,
# and ChatGPT conversations.

{ config, pkgs, ... }:

let
  # MCP servers are deployed to ~/ai/mcp from the flake sources
  mcpServersDir = "${config.home.homeDirectory}/ai/mcp";
  # Source files from the flake (relative to this file)
  mcpSourceDir = ../../mcp;
  
  # Common MCP server configurations
  mcpConfig = {
    mcpServers = {
      # Browser automation via Playwright
      browser = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "node ${config.home.homeDirectory}/mcp-browser-server/mcp_server.js"
        ];
        env = {};
        disabled = false;
      };

      # DALL-E image generation via OpenAI API
      openai-dalle = {
        command = "${mcpServersDir}/openai-dalle/run-server.sh";
        args = [];
        env = {};
        disabled = false;
      };

      # ChatGPT conversation API
      chatgpt-conversation = {
        command = "nix-shell";
        args = [
          "${mcpServersDir}/mcp-chatgpt-responses/shell.nix"
          "--run"
          "python chatgpt_server.py"
        ];
        env = {};
        disabled = false;
      };
    };
  };
in
{
  # Amazon Q CLI MCP configuration
  home.file.".aws/amazonq/mcp.json" = {
    text = builtins.toJSON mcpConfig;
  };

  # Kiro CLI MCP configuration
  home.file.".kiro/settings/mcp.json" = {
    text = builtins.toJSON mcpConfig;
  };

  # Deploy MCP server source files
  home.file."${mcpServersDir}/openai-dalle/server.py".source = "${mcpSourceDir}/openai-dalle/server.py";
  home.file."${mcpServersDir}/openai-dalle/requirements.txt".source = "${mcpSourceDir}/openai-dalle/requirements.txt";
  home.file."${mcpServersDir}/openai-dalle/README.md".source = "${mcpSourceDir}/openai-dalle/README.md";
  
  home.file."${mcpServersDir}/mcp-chatgpt-responses/chatgpt_server.py".source = "${mcpSourceDir}/mcp-chatgpt-responses/chatgpt_server.py";
  home.file."${mcpServersDir}/mcp-chatgpt-responses/requirements.txt".source = "${mcpSourceDir}/mcp-chatgpt-responses/requirements.txt";
  home.file."${mcpServersDir}/mcp-chatgpt-responses/README.md".source = "${mcpSourceDir}/mcp-chatgpt-responses/README.md";


  # OpenAI DALL-E server wrapper script
  home.file."${mcpServersDir}/openai-dalle/run-server.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      export OPENAI_API_KEY=$(cat /run/secrets/openai_api_token)
      cd ${mcpServersDir}/openai-dalle
      exec nix-shell shell.nix --run "python server.py"
    '';
  };

  # OpenAI DALL-E shell.nix
  home.file."${mcpServersDir}/openai-dalle/shell.nix" = {
    text = ''
      { pkgs ? import <nixpkgs> {} }:

      pkgs.mkShell {
        buildInputs = with pkgs; [
          python3
          python3Packages.pip
          python3Packages.virtualenv
        ];

        shellHook = '''
          if [ ! -d venv ]; then
            echo "Creating virtual environment..." >&2
            python -m venv venv >&2
          fi
          source venv/bin/activate >&2
          if [ ! -f venv/.installed ]; then
            echo "Installing dependencies..." >&2
            pip install --quiet mcp openai >&2
            touch venv/.installed
          fi
        ''';
      }
    '';
  };

  # ChatGPT conversation server shell.nix
  home.file."${mcpServersDir}/mcp-chatgpt-responses/shell.nix" = {
    text = ''
      { pkgs ? import <nixpkgs> {} }:

      pkgs.mkShell {
        buildInputs = with pkgs; [
          python3
          python3Packages.pip
          python3Packages.virtualenv
        ];

        shellHook = '''
          cd ${mcpServersDir}/mcp-chatgpt-responses
          if [ ! -d venv ]; then
            echo "Creating virtual environment..." >&2
            python -m venv venv >&2
          fi
          source venv/bin/activate >&2
          if [ ! -f venv/.installed ]; then
            echo "Installing dependencies..." >&2
            pip install --quiet -r requirements.txt >&2
            touch venv/.installed
          fi
          export OPENAI_API_KEY=$(cat /run/secrets/openai_api_token)
        ''';
      }
    '';
  };
}
