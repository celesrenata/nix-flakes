{ config, systemHostname, lib, ... }:
let
  allMachines = [
    {
      hostName = "gremlin-1";
      systems = [ "x86_64-linux" "i686-linux" ];
      protocol = "ssh";
      maxJobs = 16;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-2";
      systems = [ "x86_64-linux" "i686-linux" ];
      protocol = "ssh";
      maxJobs = 16;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-3";
      systems = [ "x86_64-linux" "i686-linux" ];
      protocol = "ssh";
      maxJobs = 16;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-4";
      systems = [ "x86_64-linux" "i686-linux" ];
      protocol = "ssh";
      maxJobs = 16;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];
in
{
  nix.distributedBuilds = true;
  nix.settings.system-features = [
    "kvm"
    "big-parallel"
    "nixos-test"
    "benchmark"
  ];
  
  # Filter out current hostname to prevent self-build loops
  nix.buildMachines = lib.filter (machine: machine.hostName != systemHostname) allMachines;
}
