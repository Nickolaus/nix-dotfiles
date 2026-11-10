{ ... }: {
  # macOS resolves an app bundle through LaunchServices, which records the
  # bundle's real path. Home Manager's default for a pre-25.11 stateVersion is
  # `targets.darwin.linkApps`, which exposes each app as a symlink into
  # /nix/store, so every version bump registers a new app identity and leaves
  # the previous store path registered. Nothing re-registers the new path, so
  # Spotlight and the Dock keep resolving an old one until garbage collection
  # deletes it, at which point launching the app fails outright. TCC grants
  # (Accessibility, Screen Recording) are keyed to the same path and are lost
  # on every upgrade for the same reason.
  #
  # `copyApps` copies the bundles into the same directory instead, so the path
  # a registration points at stays valid across upgrades. It is Home Manager's
  # own default from stateVersion 25.11 onwards; this host predates that, so it
  # opts in explicitly rather than moving its stateVersion.
  #
  # The two options assert against each other, so linkApps has to be turned off
  # in the same change. copyApps runs after linkGeneration and removes the old
  # symlinked directory itself, so no manual migration is needed.
  #
  # Activation needs the App Management permission for whatever runs
  # home-manager, and prompts for it on the first switch.
  targets.darwin = {
    linkApps.enable = false;
    copyApps.enable = true;
  };
}
