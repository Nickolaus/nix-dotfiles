{ pkgs
, lib
, flake
, ...
}: {

  imports = [
    flake.inputs.sops-nix.homeManagerModule
    ./features
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  manual.manpages.enable = false;

  # Shared environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    # Claude Code: pull in CLAUDE.md/AGENTS.md from --add-dir /
    # permissions.additionalDirectories paths, not just file access.
    # No-op for any project that doesn't set additionalDirectories.
    CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD = "1";
  };

  # Note: home.username, home.homeDirectory, and home.stateVersion
  # are defined in host-specific configs (zoidberg.nix, farnsworth.nix)
  # Each host sets its own stateVersion based on its first installation date.
}
