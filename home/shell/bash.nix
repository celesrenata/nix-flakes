# Bash shell configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    # Custom bashrc configuration
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:"
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
