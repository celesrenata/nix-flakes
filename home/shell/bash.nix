# Bash shell configuration
{ inputs, lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    # Custom bashrc configuration
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:"

      # GitHub PAT from sops secret for MCP servers (Codex, Kiro)
      if [ -r /run/secrets/github_token ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat /run/secrets/github_token)"
      fi
    '';

    # Shell aliases
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
    
    # Session variables
    sessionVariables = {
      EDITOR = "vim";
    };
  };
}
