# MCP Server Packages Overlay
# Packages MCP (Model Context Protocol) servers as proper Nix derivations.
#
# These are pre-built npm packages that ship JS in dist/ or build/.
# Uses a FOD (fixed-output derivation) for npm dependencies since
# registry tarballs don't include package-lock.json.

final: prev:

let
  # Helper: builds a pre-compiled MCP npm package from registry tarball.
  buildMcpServer =
    {
      pname,
      version,
      npmName,
      tarballName,
      entry,
      hash,
      depsHash,
      bin ? pname,
      description,
    }:

    let
      src = final.fetchurl {
        url = "https://registry.npmjs.org/${npmName}/-/${tarballName}-${version}.tgz";
        inherit hash;
      };

      # Fixed-output derivation that installs npm dependencies.
      deps = final.stdenv.mkDerivation {
        name = "${pname}-${version}-deps";
        inherit src;
        sourceRoot = "package";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = depsHash;
        nativeBuildInputs = [ final.nodejs final.cacert ];
        buildPhase = ''
          export HOME=$TMPDIR
          npm install --omit=dev --ignore-scripts --no-audit --no-fund
        '';
        installPhase = ''
          mkdir -p $out
          cp -r node_modules $out/
        '';
      };
    in
    final.stdenv.mkDerivation {
      inherit pname version src;
      sourceRoot = "package";

      nativeBuildInputs = [ final.makeWrapper ];

      installPhase = ''
        runHook preInstall

        packageDir="$out/lib/node_modules/${npmName}"
        mkdir -p "$(dirname "$packageDir")" "$out/bin"

        cp -r . "$packageDir"
        ln -s ${deps}/node_modules "$packageDir/node_modules"

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
  mcp-server-sequential-thinking = buildMcpServer {
    pname = "mcp-server-sequential-thinking";
    version = "2025.12.18";
    npmName = "@modelcontextprotocol/server-sequential-thinking";
    tarballName = "server-sequential-thinking";
    entry = "dist/index.js";
    bin = "mcp-server-sequential-thinking";
    hash = "sha256-WiHm+kc3IrjmIqm7vdcrxtvN30MPJqtZic0z3+XcdwM=";
    depsHash = "sha256-iX0+iMMOO1ImuFeb7K4uX6YvBUbQMiHQNEk2AKwl/zI=";
    description = "MCP server for structured sequential thinking and problem decomposition";
  };

  mcp-server-memory = buildMcpServer {
    pname = "mcp-server-memory";
    version = "2026.1.26";
    npmName = "@modelcontextprotocol/server-memory";
    tarballName = "server-memory";
    entry = "dist/index.js";
    bin = "mcp-server-memory";
    hash = "sha256-cD9iexZwFnV0ofEZAxgWSBvgENaLcv8JypuZ1x5e9SQ=";
    depsHash = "sha256-RDOBfPgOI6gtYG8CYDkGGqy0OiGNXTIpoRBPWDrgLfQ=";
    description = "MCP server providing persistent knowledge graph memory";
  };

  mcp-server-github = buildMcpServer {
    pname = "mcp-server-github";
    version = "2025.4.8";
    npmName = "@modelcontextprotocol/server-github";
    tarballName = "server-github";
    entry = "dist/index.js";
    bin = "mcp-server-github";
    hash = "sha256-HVsbypMFrfDIBVEx8ihlFMm+pusxEARgiZoe2f/s5cE=";
    depsHash = "sha256-KbcTUqhAxGKKDbRsIQShmuPjDuLcNoNFgLnc8nND+JM=";
    description = "MCP server for GitHub repository interaction";
  };

  any-chat-completions-mcp = buildMcpServer {
    pname = "any-chat-completions-mcp";
    version = "0.1.1";
    npmName = "@pyroprompts/any-chat-completions-mcp";
    tarballName = "any-chat-completions-mcp";
    entry = "build/index.js";
    bin = "any-chat-completions-mcp";
    hash = "sha256-IA1PNlF7pmt3H1nSzxpZ32bxsml7SS6UVrkp0Djw4IM=";
    depsHash = "sha256-gKJW3FPL7C8ocgqiSw+69GyQCM+JKhI+hE56pAtOcQM=";
    description = "MCP server bridging to any OpenAI-compatible chat completions API";
  };
}
