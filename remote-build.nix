{ ... }:
{
  nix.buildMachines = [ 
    {
      hostName = "localhost";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
    {
      hostName = "goblin-1";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
    {
      hostName = "goblin-2";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
    {
      hostName = "goblin-3";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" ];
    }
  ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
    trusted-users = root celes
  '';
}
