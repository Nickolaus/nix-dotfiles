{ config, pkgs, lib, ... }:

# Btrfs maintenance automation
# Prevents space issues and maintains filesystem health
# Critical for long-term Btrfs reliability

{
  # Automatic scrubbing (data integrity check)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Automatic balance (space reclamation)
  systemd.services.btrfs-balance = {
    description = "Balance Btrfs filesystem";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=50 -musage=50 /";
    };
  };

  systemd.timers.btrfs-balance = {
    description = "Balance Btrfs filesystem monthly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
    };
  };

  # Automatic defragmentation (for specific paths)
  systemd.services.btrfs-defrag = {
    description = "Defragment Btrfs filesystem";
    serviceConfig = {
      Type = "oneshot";
      # Defrag home and persist, but NOT /nix (read-only store)
      ExecStart = pkgs.writeShellScript "btrfs-defrag" ''
        ${pkgs.btrfs-progs}/bin/btrfs filesystem defragment -r -czstd /home || true
        ${pkgs.btrfs-progs}/bin/btrfs filesystem defragment -r -czstd /persist || true
      '';
    };
  };

  systemd.timers.btrfs-defrag = {
    description = "Defragment Btrfs filesystem monthly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
    };
  };

  # Snapshot management - automatic cleanup of old snapshots
  systemd.services.btrfs-snapshot-cleanup = {
    description = "Clean up old Btrfs snapshots";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "snapshot-cleanup" ''
        # Keep last 10 snapshots, delete older
        ${pkgs.btrfs-progs}/bin/btrfs subvolume list -s /.snapshots | \
          tail -n +11 | \
          awk '{print $2}' | \
          xargs -I {} ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /.snapshots/{} || true
      '';
    };
  };

  systemd.timers.btrfs-snapshot-cleanup = {
    description = "Clean up old snapshots weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Pre-update snapshot script
  # Create a snapshot before system updates
  systemd.services.nixos-pre-update-snapshot = {
    description = "Create Btrfs snapshot before NixOS update";
    before = [ "nixos-upgrade.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "pre-update-snapshot" ''
        SNAPSHOT_NAME="root-$(date +%Y%m%d-%H%M%S)"
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot / /.snapshots/$SNAPSHOT_NAME
        echo "Created snapshot: $SNAPSHOT_NAME"
      '';
    };
  };

  # Btrfs filesystem monitoring
  systemd.services.btrfs-usage-check = {
    description = "Check Btrfs filesystem usage and warn if high";
    serviceConfig = {
      Type = "oneshot";
      User = "C.Hessel";
      ExecStart = pkgs.writeShellScript "btrfs-usage-check" ''
        USAGE=$(${pkgs.btrfs-progs}/bin/btrfs filesystem usage / | grep "Free (estimated)" | awk '{print $3}' | tr -d 'GiB')
        
        if [ "$USAGE" -lt 10 ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical "Btrfs Warning" "Less than 10GB free space remaining!"
        fi
      '';
    };
  };

  systemd.timers.btrfs-usage-check = {
    description = "Check Btrfs usage daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Helper script for manual operations
  environment.systemPackages = with pkgs; [
    btrfs-progs  # Btrfs utilities
    compsize     # Check compression ratio
    
    # Create helper script
    (writeShellScriptBin "btrfs-snapshot" ''
      # Create a manual snapshot
      SNAPSHOT_NAME="manual-$(date +%Y%m%d-%H%M%S)"
      ${btrfs-progs}/bin/btrfs subvolume snapshot / /.snapshots/$SNAPSHOT_NAME
      echo "Created snapshot: $SNAPSHOT_NAME"
      echo "Snapshots location: /.snapshots/"
    '')
    
    (writeShellScriptBin "btrfs-status" ''
      # Show Btrfs filesystem status
      echo "=== Btrfs Filesystem Usage ==="
      ${btrfs-progs}/bin/btrfs filesystem usage /
      
      echo -e "\n=== Btrfs Device Stats ==="
      ${btrfs-progs}/bin/btrfs device stats /
      
      echo -e "\n=== Available Snapshots ==="
      ${btrfs-progs}/bin/btrfs subvolume list -s /.snapshots
      
      echo -e "\n=== Compression Ratio ==="
      ${compsize}/bin/compsize / 2>/dev/null || echo "Run as root for compression info"
    '')
  ];
}

