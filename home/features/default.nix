{ ... }: {
  imports = [
    ./packages.nix
    ./cache-hygiene.nix
    ./shell
    ./git
    ./ssh
    ./editors
    ./secrets
    ./terminals
    ./development
    ./ai
    ./darwin
    ./linux
  ];
} 