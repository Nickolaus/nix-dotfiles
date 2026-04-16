{ config
, pkgs
, lib
, ...
}:
let
  primaryFingerprint = "3B0192CAE5EC81B9E854C42ACE81684EB4C0893B";
  expectedFingerprint = "CFFB43C92C5C89E8E88BC4C84308BD8948326B5C";
  sopsAgentLabel = "org.nix-community.home.sops-nix";
  importAgentLabel = "org.nix-community.home.homelab-gpg-import";
  logDir = "${config.home.homeDirectory}/.local/state/homelab";
  secretPath = config.sops.secrets.homelab_gpg_signing_subkey.path;
  gpgBin = "${pkgs.gnupg}/bin/gpg";
  homelabGpgImport = pkgs.writeShellScriptBin "homelab-gpg-import" ''
    #!/usr/bin/env bash
    set -euo pipefail

    secret_path="${secretPath}"
    primary_fingerprint="${primaryFingerprint}"
    expected_fingerprint="${expectedFingerprint}"
    gnupg_home="$HOME/.gnupg"
    state_dir="${logDir}"
    hash_file="$state_dir/gpg-import.sha256"
    gpg_bin="${gpgBin}"

    ensure_ownertrust() {
      printf '%s:6:\n' "$primary_fingerprint" | "$gpg_bin" --batch --yes --homedir "$gnupg_home" --import-ownertrust >/dev/null 2>&1 || true
    }

    mkdir -p "$state_dir"

    for _ in $(seq 1 30); do
      if [[ -s "$secret_path" ]]; then
        break
      fi
      sleep 1
    done

    if [[ ! -s "$secret_path" ]]; then
      echo "Secret file not available: $secret_path" >&2
      exit 1
    fi

    mkdir -p "$gnupg_home"
    chmod 700 "$gnupg_home"

    secret_hash="$(/usr/bin/shasum -a 256 "$secret_path" | /usr/bin/awk '{print $1}')"
    current_hash=""
    if [[ -f "$hash_file" ]]; then
      current_hash="$(<"$hash_file")"
    fi

    if [[ "$secret_hash" == "$current_hash" ]] && "$gpg_bin" --batch --homedir "$gnupg_home" --list-secret-keys "$expected_fingerprint" >/dev/null 2>&1; then
      ensure_ownertrust
      echo "Signing subkey already present and secret unchanged."
      exit 0
    fi

    "$gpg_bin" --batch --yes --homedir "$gnupg_home" --import "$secret_path" >/dev/null
    ensure_ownertrust

    if ! "$gpg_bin" --batch --homedir "$gnupg_home" --list-secret-keys "$expected_fingerprint" >/dev/null 2>&1; then
      echo "Expected signing subkey not present after import: $expected_fingerprint" >&2
      exit 1
    fi

    printf '%s\n' "$secret_hash" > "$hash_file"
    chmod 600 "$hash_file"
    echo "Imported signing subkey for $expected_fingerprint into $gnupg_home"
  '';
  hmSecretsStatus = pkgs.writeShellScriptBin "hm-secrets-status" ''
    #!/usr/bin/env bash
    set -euo pipefail

    secrets_dir="$HOME/.config/sops-nix/secrets"
    secret_path="${secretPath}"
    expected_fingerprint="${expectedFingerprint}"
    gpg_bin="${gpgBin}"

    echo "== Home Manager SOPS =="
    echo "Secrets dir: $secrets_dir"
    if [[ -L "$secrets_dir" || -d "$secrets_dir" ]]; then
      /bin/ls -ld "$secrets_dir"
    else
      echo "missing"
    fi

    echo
    echo "SOPS agent: ${sopsAgentLabel}"
    if /bin/launchctl print "gui/$(/usr/bin/id -u)/${sopsAgentLabel}" >/dev/null 2>&1; then
      /bin/launchctl print "gui/$(/usr/bin/id -u)/${sopsAgentLabel}" | /usr/bin/grep -E 'state =|last exit code =' || true
    else
      echo "not loaded"
    fi

    echo
    echo "GPG import agent: ${importAgentLabel}"
    if /bin/launchctl print "gui/$(/usr/bin/id -u)/${importAgentLabel}" >/dev/null 2>&1; then
      /bin/launchctl print "gui/$(/usr/bin/id -u)/${importAgentLabel}" | /usr/bin/grep -E 'state =|last exit code =' || true
    else
      echo "not loaded"
    fi

    echo
    echo "Secret path: $secret_path"
    if [[ -L "$secret_path" || -f "$secret_path" ]]; then
      /bin/ls -l "$secret_path"
      if [[ -s "$secret_path" ]]; then
        echo "secret file is present and non-empty"
      else
        echo "secret file exists but is empty"
      fi
    else
      echo "missing"
    fi

    echo
    echo "GPG secret key check (~/.gnupg):"
    if "$gpg_bin" --batch --homedir "$HOME/.gnupg" --list-secret-keys "$expected_fingerprint" >/dev/null 2>&1; then
      echo "present: $expected_fingerprint"
    else
      echo "missing: $expected_fingerprint"
    fi

    echo
    echo "Logs:"
    echo "  ${logDir}/gpg-import.log"
    echo "  ${logDir}/gpg-import.error.log"
    echo "  $HOME/Library/Logs/SopsNix/stdout"
    echo "  $HOME/Library/Logs/SopsNix/stderr"
  '';
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [
    pkgs.gnupg
    homelabGpgImport
    hmSecretsStatus
  ];

  home.file.".local/state/homelab/.keep".text = "";

  launchd.agents.homelab-gpg-import = {
    enable = true;
    config = {
      ProgramArguments = [ "${homelabGpgImport}/bin/homelab-gpg-import" ];
      RunAtLoad = true;
      KeepAlive = false;
      WatchPaths = [ secretPath ];
      StandardOutPath = "${logDir}/gpg-import.log";
      StandardErrorPath = "${logDir}/gpg-import.error.log";
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = config.home.homeDirectory;
      };
    };
  };
}
