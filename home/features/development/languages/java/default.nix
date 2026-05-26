{ pkgs, ... }:
let
  jdk = pkgs.jdk17;
in
{
  home.packages = [
    jdk
  ];

  home.sessionVariables = {
    JAVA_HOME = jdk.home;
  };
}
