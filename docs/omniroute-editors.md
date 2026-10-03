# OmniRoute editor clients on esnixi

Home Manager configures esnixi's editors to use the OmniRoute instance on
stabulous without exposing it to the LAN. The user service
`omniroute-stabulous-tunnel` forwards esnixi's `127.0.0.1:20128` through SSH to
stabulous's loopback-only OmniRoute listener.

Configured clients:

- JetBrains Air: four Codex ACP agents in
  `~/.config/JetBrains/Air/acp.json` (`local/code`, `hybrid/code`, `free/code`,
  and `local/long`).
- VS Code: Zoo. Home Manager removes Continue on activation from both local
  and Remote SSH extension directories because it conflicts with Zoo.
- Kiro: OmniCopilot, filtered to OmniRoute's local, free, hybrid, and cloud
  logical routes.
- PyCharm: Continue, using `~/.continue/config.yaml`.

The declarative source is `home/programs/omniroute-editors.nix`. Apply it with
the esnixi Home Manager configuration, then reload any editor that was already
open. Check connectivity with:

```console
systemctl --user status omniroute-stabulous-tunnel.service
curl http://127.0.0.1:20128/api/health
```

No provider secret is copied to esnixi. Cloud and free-provider credentials
remain in the stabulous OmniRoute process. The `omniroute-local` value supplied
to local clients is only a compatibility placeholder for clients that require
an API-key field.
