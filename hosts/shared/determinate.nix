{ pkgs
, ...
}: {
  # determinate-nixd's collector, declared rather than left to the installer's
  # default. It keeps 5-20% of the disk free, which is a safety net against a
  # full disk but not a substitute for pruning generations - every retained
  # generation is a live GC root, so the collector cannot reclaim it. Darwin
  # hosts get scheduled generation pruning from ./nix-gc-darwin.nix; NixOS hosts
  # use `nix.gc` in their own host module.
  environment.etc."determinate/config.json".text = builtins.toJSON {
    garbageCollector.strategy = "automatic";
  };

  environment.etc."nix/nix.custom.conf".text = ''
    lazy-trees = true
    auto-optimise-store = true
    trusted-users = root C.Hessel
    extra-substituters = https://devenv.cachix.org
    trusted-substituters = https://cachix.cachix.org https://nixpkgs.cachix.org https://devenv.cachix.org
    trusted-public-keys = cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM= nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';
}
