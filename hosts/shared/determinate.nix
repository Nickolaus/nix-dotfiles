{ pkgs
, ...
}: {
  environment.etc."nix/nix.custom.conf".text = ''
    lazy-trees = true
    auto-optimise-store = true
    trusted-users = root C.Hessel
    extra-substituters = https://devenv.cachix.org
    trusted-substituters = https://cachix.cachix.org https://nixpkgs.cachix.org https://devenv.cachix.org
    trusted-public-keys = cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM= nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';
}
