{ sops
, config
, pkgs
, ...
}: {
  sops = {
    age.keyFile = "${
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/Users/C.Hessel/Library/Application Support/sops/age/keys.txt"
    else "/home/C.Hessel/.config/sops/age/keys.txt"
    }";

    defaultSopsFile = ./secrets.yaml;

    secrets.ssh_key = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      format = "yaml";
      mode = "0600";
    };

    secrets.ssh_key_personal = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_personal";
      format = "yaml";
      mode = "0600";
    };

    secrets.openai_api_key = {
      path = "${config.home.homeDirectory}/.config/opencommit/openai_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.claude_api_key = {
      path = "${config.home.homeDirectory}/.config/opencommit/claude_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.github_token = {
      path = "${config.home.homeDirectory}/.config/nix/github_token";
      format = "yaml";
      mode = "0600";
    };
  };
}
