{ pkgs
, ...
}:

# Scheduled Nix garbage collection for Determinate hosts on darwin.
#
# Determinate owns /etc/nix/nix.conf, so these hosts set `nix.enable = false`,
# which also removes nix-darwin's `nix.gc.automatic` and `nix.optimise.automatic`
# options. That leaves determinate-nixd as the only collector, and it targets
# 5-20% free space rather than a fixed reserve - on a 1 TB disk it is satisfied
# at ~70 GB free, which is less than a single system closure needs to build.
#
# determinate-nixd also only deletes paths that are already dead. Retained
# profile generations are live GC roots, so without a job that prunes them the
# store grows monotonically no matter how often the collector runs. This daemon
# prunes generations first, then collects.
#
# Needs nh >= 4.5.0, which preserves the generation each profile symlink points
# at even when it falls outside --keep and --keep-since. Without that, rolling
# back and then not rebuilding for longer than the retention window lets this
# daemon delete the running generation and leave the profile dangling. Do not
# add --delete-current: that flag opts back into the old behaviour.
#
# determinate-nixd stays on `automatic` as the low-disk safety net between runs;
# see hosts/shared/determinate.nix.

let
  retentionDays = 45;
  keepGenerations = 5;
  logDir = "/var/log/nix-gc";

  gcScript = pkgs.writeShellScript "nix-gc-weekly" ''
    set -euo pipefail
    export PATH="/nix/var/nix/profiles/default/bin:${pkgs.coreutils}/bin:$PATH"

    echo "=== nix-gc $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

    # nh resolves an elevation program unconditionally and panics when it
    # cannot, so --elevation-strategy=none is only valid as root. launchd
    # daemons run as root; this check turns a manual non-root run into a
    # readable error instead of a Rust backtrace.
    if [ "$(id -u)" -ne 0 ]; then
      echo "nix-gc must run as root (nh cannot self-elevate from a daemon)" >&2
      exit 1
    fi

    df -Pk /nix/store | awk 'NR == 2 { printf "before: %.1f GiB free\n", $4 / 1024 / 1024 }'

    # No --optimise: auto-optimise-store is on (hosts/shared/determinate.nix), so
    # paths are hard-linked as they are written and an optimise pass reclaims
    # nothing while still hashing the whole store. Measured on this host:
    # "hard linking is currently saving 20.8 GiB" alongside
    # "0.0 KiB freed by hard-linking 0 files".
    ${pkgs.nh}/bin/nh clean all \
      --keep ${toString keepGenerations} \
      --keep-since ${toString retentionDays}d \
      --elevation-strategy none

    df -Pk /nix/store | awk 'NR == 2 { printf "after: %.1f GiB free\n", $4 / 1024 / 1024 }'
  '';
in
{
  system.activationScripts.nixGcLogDir.text = ''
    mkdir -p ${logDir}
  '';

  launchd.daemons.nix-gc = {
    script = "exec ${gcScript}";

    serviceConfig = {
      # Sunday 03:30. launchd runs a missed StartCalendarInterval job once the
      # machine wakes, so a laptop that sleeps through the window still gets
      # collected rather than skipping the week.
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 3;
          Minute = 30;
        }
      ];
      StandardOutPath = "${logDir}/nix-gc.log";
      StandardErrorPath = "${logDir}/nix-gc.error.log";
      # GC is IO-heavy and never urgent; Background throttles its IO.
      ProcessType = "Background";
    };
  };
}
