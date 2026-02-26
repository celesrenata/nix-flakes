{ ... }:
{
  services.exo = {
    enable = true;
    accelerator = "cpu";  # Changed from "cuda" to "cpu" for Linux compatibility
    port = 52415;
    openFirewall = true;
  };
}
