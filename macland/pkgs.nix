{ ... }:

{
  # Use the pre-configured pkgs from let binding
  nixpkgs.pkgs = import ../. { };
}
