{ ... }:
{
  nix.buildMachines = [
  #{
  #  hostName = "localhost";
  #  systems = [ "x86_64-linux" ];
  #  protocol = "ssh-ng";
  #  maxJobs = 4;
  #  speedFactor = 2;
  #  supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  #}
  {
    hostName = "gremlin-2";
    systems = [ "x86_64-linux" ];
    protocol = "ssh-ng";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  } 
  {
    hostName = "gremlin-3";
    systems = [ "x86_64-linux" ];
    protocol = "ssh-ng";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  } 
 ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
