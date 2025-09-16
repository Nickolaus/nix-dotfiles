{ pkgs, config, ... }: {

  programs.go = {
    enable = true;
    package = pkgs.go;
    env = {
      GOPATH = "${config.home.homeDirectory}/.go";
    };
  };
}
