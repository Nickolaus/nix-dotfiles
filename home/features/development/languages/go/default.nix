{ pkgs, config, ... }:
let
  goPath = "${config.home.homeDirectory}/.go";
in
{

  programs.go = {
    enable = true;
    package = pkgs.go;
    env = {
      GOPATH = goPath;
    };
  };

  home.sessionVariables = {
    GOPATH = goPath;
  };

  home.packages = with pkgs; [
    gopls
    delve
    golangci-lint
    go-tools
  ];
}
