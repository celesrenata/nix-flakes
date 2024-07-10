{ ... }:
{
  nix.buildMachines = [ 
    {
      hostName = "localhost";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 0;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
    {
      hostName = "a2nix";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 8;
      speedFactor = 20;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
  ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
