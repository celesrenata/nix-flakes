# MCP Server Packages Overlay
# Packages MCP (Model Context Protocol) servers as proper Nix derivations.
#
# Hash placeholders:
# - Replace every `hash = "";` with the hash reported by `nix build`.
# - Replace every `npmDepsHash = "";` with the hash reported by `nix build`.
#
# These packages ship prebuilt JS in dist/ or build/, so
# `dontNpmBuild = true` skips the build step.

final: prev:

let
  buildMcpNpmPackage =
    {
      pname,
      version,
      npmName,
      tarballName,
      entry,
      bin ? pname,
      description,
    }:

    final.buildNpmPackage rec {
      inherit pname version;

      src = final.fetchurl {
        url = "https://registry.npmjs.org/${npmName}/-/${tarballName}-${version}.tgz";
        # Run `nix build` and replace with the reported hash.
        hash = "";
      };

      # npm registry tarballs unpack into a top-level `package/` directory.
      sourceRoot = "package";

      # Run `nix build` and replace with the reported hash.
      npmDepsHash = "";

      # These npm packages already ship compiled JS.
      dontNpmBuild = true;

      nativeBuildInputs = [
        final.makeWrapper
      ];

      installPhase = ''
        runHook preInstall

        packageDir="$out/lib/node_modules/${npmName}"
        mkdir -p "$(dirname "$packageDir")" "$out/bin"

        # Copy package contents, including node_modules produced by buildNpmPackage.
        cp -r . "$packageDir"

        # Provide a stable executable wrapper.
        makeWrapper "${final.nodejs}/bin/node" "$out/bin/${bin}" \
          --add-flags "$packageDir/${entry}"

        runHook postInstall
      '';

      meta = with final.lib; {
        inherit description;
        homepage = "https://www.npmjs.com/package/${npmName}";
        mainProgram = bin;
        platforms = platforms.all;
      };
    };
in
{
  mcp-server-sequential-thinking = buildMcpNpmPackage {
    pname = "mcp-server-sequential-thinking";
    version = "2025.12.18";
    npmName = "@modelcontextprotocol/server-sequential-thinking";
    tarballName = "server-sequential-thinking";
    entry = "dist/index.js";
    bin = "mcp-server-sequential-thinking";
    description = "MCP server for structured sequential thinking and problem decomposition";
  };

  mcp-server-memory = buildMcpNpmPackage {
    pname = "mcp-server-memory";
    version = "2026.1.26";
    npmName = "@modelcontextprotocol/server-memory";
    tarballName = "server-memory";
    entry = "dist/index.js";
    bin = "mcp-server-memory";
    description = "MCP server providing persistent knowledge graph memory";
  };

  mcp-server-github = buildMcpNpmPackage {
    pname = "mcp-server-github";
    version = "2025.4.8";
    npmName = "@modelcontextprotocol/server-github";
    tarballName = "server-github";
    entry = "dist/index.js";
    bin = "mcp-server-github";
    description = "MCP server for GitHub repository interaction";
  };

  any-chat-completions-mcp = buildMcpNpmPackage {
    pname = "any-chat-completions-mcp";
    version = "0.1.1";
    npmName = "@pyroprompts/any-chat-completions-mcp";
    tarballName = "any-chat-completions-mcp";
    entry = "build/index.js";
    bin = "any-chat-completions-mcp";
    description = "MCP server bridging to any OpenAI-compatible chat completions API";
  };
}
