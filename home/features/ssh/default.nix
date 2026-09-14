{ config, lib, ... }:
let
  cfg = config.sshKeys;

  # Each scope contributes one match block per host it answers for, carrying
  # that scope's identities in offer order. Per-host options win over the
  # shared identity settings. A single-element list renders exactly like a
  # bare string, so scopes that hold one key produce the config they always did.
  blocksFor = scope: key:
    lib.mapAttrs
      (_host: opts: {
        IdentityFile = cfg.scopePaths scope;
        IdentitiesOnly = true;
      } // opts)
      key.hosts;
in
{
  imports = [
    ./keys.nix
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = lib.foldl' lib.mergeAttrs { "*" = cfg.defaults; }
      (lib.mapAttrsToList blocksFor cfg.scopes);
  };
}
