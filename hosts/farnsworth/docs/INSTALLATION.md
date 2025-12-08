# Farnsworth Installation Guide

Complete guide for installing farnsworth NixOS configuration using **nixos-anywhere** - the modern, automated approach that works for both VM testing and production hardware.

---

## 📋 Overview

**nixos-anywhere** installs NixOS remotely over SSH from your macOS machine. This means:
- ✅ No manual partitioning or formatting
- ✅ No typing commands in the target system
- ✅ Fully automated, declarative installation
- ✅ Same process for VM testing and production hardware
- ✅ Can reinstall/update easily

**Installation Flow:**
```
macOS (your dotfiles) → SSH → Target System → Fully configured farnsworth
```

---

## 🎯 Installation Scenarios

This guide covers three scenarios with the **same process**:

1. **VM Testing** (UTM on macOS) - Test your config safely
2. **Production Laptop** (Real hardware) - Deploy to actual laptop
3. **Remote Server** (Over network) - Install to remote machine

---

## ⚠️ Prerequisites

### On Your macOS Machine

**Required:**
- ✅ Nix with flakes enabled (you have this)
- ✅ Your dotfiles cloned: `~/.config/nix-dotfiles`
- ✅ SSH access to target system
- ✅ Network connection to target

**Install nixos-anywhere:**
```bash
# nixos-anywhere will be run via nix run, no installation needed
```

### On Target System

**Minimal Requirements:**
- ✅ Booted into any Linux with SSH enabled
- ✅ Network connectivity
- ✅ Root SSH access

**Options for getting SSH access:**
1. **NixOS ISO** (recommended) - Boot from USB/ISO, enable SSH
2. **Existing Linux** - Any live Linux with SSH
3. **Recovery mode** - If system already has Linux

---

## 🚀 Part 1: Prepare Target System

### Option A: VM Testing (UTM)

**1. Create UTM VM:**
```bash
# Run the setup script
cd ~/.config/nix-dotfiles
./vm-test-setup.sh
```

**2. Boot minimal NixOS ISO in UTM:**
- Memory: 8 GB
- CPU: 4 cores  
- Storage: 64 GB
- Network: Shared (default)

**3. Enable SSH in VM:**
```bash
# In VM console (after boot, login as nixos)
sudo systemctl start sshd

# Set root password for SSH
sudo passwd
# Enter: test123 (or whatever you want)

# Get VM IP address
ip addr show
# Look for IP like: 192.168.64.X
```

**4. Test SSH from macOS:**
```bash
# From macOS terminal
ssh root@192.168.64.X
# Enter password, then exit
```

---

### Option B: Production Laptop

**1. Prepare bootable USB:**
```bash
# Download NixOS ISO (on macOS)
cd ~/Downloads

# For ARM laptop
curl -LO https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-aarch64-linux.iso

# For x86_64 laptop
curl -LO https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso

# Write to USB (find disk with: diskutil list)
sudo dd if=nixos-minimal-*.iso of=/dev/diskX bs=4m status=progress
```

**2. Boot laptop from USB:**
- Insert USB drive
- Enter BIOS/UEFI (usually F2, F12, Del, or Esc)
- Disable Secure Boot (temporarily)
- Boot from USB drive

**3. Connect to network:**

**WiFi:**
```bash
# In laptop console
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YourWiFiName"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Verify connection
ping -c 3 nixos.org
```

**Ethernet:**
```bash
# Should work automatically
ping -c 3 nixos.org
```

**4. Enable SSH:**
```bash
# Set root password
sudo passwd
# Enter a temporary password

# Start SSH
sudo systemctl start sshd

# Get IP address
ip addr show
# Note the IP (e.g., 192.168.1.100)
```

**5. Test SSH from macOS:**
```bash
# From macOS (on same network)
ssh root@LAPTOP_IP
# Enter password, then exit
```

---

## 💾 Part 2: Prepare Configuration

### 1. Update Disk Device Path

**For VM:**
```bash
cd ~/.config/nix-dotfiles

# Edit disko config
vim hosts/farnsworth/disko.nix

# Change line 10 to:
diskDevice = "/dev/vda";  # Standard for VMs
```

**For Production Laptop:**
```bash
# First, SSH to laptop and check disk name
ssh root@LAPTOP_IP lsblk

# Common disk names:
# - /dev/nvme0n1 (NVMe SSD)
# - /dev/sda (SATA)
# - /dev/mmcblk0 (eMMC)

# Edit disko config
vim hosts/farnsworth/disko.nix

# Change line 10 to your actual disk:
diskDevice = "/dev/nvme0n1";  # Or whatever lsblk showed
```

### 2. Choose Architecture

**For ARM system:**
```bash
# Use: .#farnsworth (default is ARM)
```

**For x86_64 system:**
```bash
# Use: .#farnsworth-x86
```

### 3. Set Encryption Password

**Create password file:**
```bash
cd ~/.config/nix-dotfiles

# For testing (simple password)
echo "test123" > /tmp/disko-password

# For production (strong password)
echo "YourStrongPassword123!" > /tmp/disko-password

# Secure it
chmod 600 /tmp/disko-password
```

---

## 🎯 Part 3: Install with nixos-anywhere

### Basic Installation

**For VM (ARM):**
```bash
cd ~/.config/nix-dotfiles

nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@192.168.64.X
```

**For Production Laptop (ARM):**
```bash
cd ~/.config/nix-dotfiles

nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@LAPTOP_IP
```

**For Production Laptop (x86_64):**
```bash
cd ~/.config/nix-dotfiles

nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth-x86 \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@LAPTOP_IP
```

### What Happens During Installation

The script will:
1. ✅ Connect via SSH to target
2. ✅ Partition disk (via disko)
3. ✅ Setup LUKS encryption
4. ✅ Create Btrfs subvolumes
5. ✅ Install NixOS with your config
6. ✅ Configure bootloader
7. ✅ Set up impermanence
8. ✅ Install all packages
9. ✅ Configure Hyprland + Waybar
10. ✅ Reboot into new system

**Time:** 15-30 minutes depending on internet speed.

### Advanced Options

**Debug mode (see what's happening):**
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  --debug \
  root@TARGET_IP
```

**Keep SSH connection open:**
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  --no-reboot \
  root@TARGET_IP
```

**Use SSH key instead of password:**
```bash
# Copy your SSH key first
ssh-copy-id root@TARGET_IP

# Then install without password prompt
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@TARGET_IP
```

---

## 🎉 Part 4: First Boot

### 1. Reboot Target System

**For VM:**
- UTM will reboot automatically
- Remove ISO from CD drive in UTM settings

**For Laptop:**
- Remove USB drive
- System will reboot automatically

### 2. Unlock Disk Encryption

At boot, you'll see:
```
Please enter passphrase for disk cryptroot:
```

Enter the password you set in `/tmp/disko-password`.

### 3. Login

**greetd login screen appears:**
```
Username: C.Hessel
Password: (needs to be set - see below)
```

**First-time password setup:**

If login fails (no password set), switch to TTY:
- Press `Ctrl+Alt+F2` (or `Ctrl+Fn+Alt+F2` on Mac keyboard)
- Login as root (no password initially)
- Set user password:
  ```bash
  passwd C.Hessel
  # Enter your password
  ```
- Switch back: `Ctrl+Alt+F1`
- Login with new password

### 4. Hyprland Starts

After login, Hyprland should start automatically with:
- ✅ Waybar at top
- ✅ Wallpaper (if configured)
- ✅ Ready for use

---

## 🧪 Part 5: Verify Installation

### Basic Tests

**Open terminal:** `SUPER + RETURN`

```bash
# Check system version
nixos-version

# Check filesystem
df -h
lsblk

# Check Btrfs
btrfs-status

# Check services
systemctl status docker
systemctl status NetworkManager

# Check encryption
sudo cryptsetup status cryptroot

# Test internet
ping -c 3 nixos.org

# Check Hyprland
echo $XDG_CURRENT_DESKTOP  # Should show: Hyprland
```

### Test Configuration Changes

```bash
cd ~/.config/nix-dotfiles

# Make a change (e.g., add neofetch)
vim hosts/farnsworth/default.nix
# Add 'neofetch' to environment.systemPackages

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth

# Test
neofetch
```

### Test Impermanence

```bash
# Create test file in root
sudo touch /test-file
ls /test-file  # Should exist

# Reboot
sudo reboot

# After reboot, check
ls /test-file  # Should NOT exist (wiped)

# But persistent data remains
ls /home/C.Hessel  # Your files still here
ls /persist  # Persistent system state
```

---

## 🔧 Part 6: Post-Installation Setup

### 1. Enable TPM2 Auto-Unlock (Optional - Production Only)

**Note:** VMs typically don't have TPM2. Skip for VM testing.

```bash
# On production laptop
sudo systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto

# Test by rebooting - should auto-unlock
sudo reboot
```

### 2. Setup FIDO2/YubiKey Unlock (Optional)

```bash
# Enroll YubiKey
sudo systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto

# Update config to enable
vim hosts/farnsworth/default.nix
# Uncomment: boot.initrd.luks.devices."cryptroot".yubikey.enable = true;

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth
```

### 3. Enable GPU Drivers (Production Only)

```bash
# Edit config
vim hosts/farnsworth/default.nix

# For NVIDIA:
# hardware.nvidia.enable = true;

# For AMD:
# hardware.amdgpu.enable = true;

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth

# Reboot for GPU drivers
sudo reboot
```

### 4. Setup Flatpak Apps

```bash
# Edit Flatpak config
vim modules/nixos/flatpak/default.nix

# Add apps to flatpakApps list:
# "com.spotify.Client"
# "com.slack.Slack"

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth

# Apps install automatically
```

### 5. Configure WiFi (If not done during install)

```bash
# GUI method (in Hyprland)
# Click network icon in Waybar
# Or: SUPER + D, type "network"

# CLI method
nmtui
```

---

## 🔄 Updating the System

### Update Configuration

```bash
cd ~/.config/nix-dotfiles

# Pull latest changes (if using git)
git pull

# Update flake inputs
nix flake update

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth
```

### Reinstall from macOS (if needed)

```bash
# Same command as initial install
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@TARGET_IP
```

**This will:**
- ⚠️ WIPE the system
- ✅ Reinstall from scratch
- ✅ Apply latest config

---

## 🐛 Troubleshooting

### Installation Fails

**Error: "Cannot connect to SSH"**
```bash
# Check target is reachable
ping TARGET_IP

# Check SSH is running on target
ssh root@TARGET_IP systemctl status sshd

# Check firewall (on target)
ssh root@TARGET_IP iptables -L
```

**Error: "Disk already has data"**
```bash
# nixos-anywhere will wipe disk automatically
# If it complains, manually wipe on target:
ssh root@TARGET_IP
wipefs -a /dev/vda  # Or your disk
```

**Error: "Cannot find flake"**
```bash
# Ensure you're in dotfiles directory
cd ~/.config/nix-dotfiles
pwd  # Should show: /Users/C.Hessel/.config/nix-dotfiles

# Check flake is valid
nix flake check
```

### System Won't Boot

**Stuck at encryption prompt:**
- Check you're entering correct password
- Password is case-sensitive
- Try typing slowly

**Boots to emergency shell:**
```bash
# Check disk mounts
mount | grep /mnt

# Check encryption
cryptsetup status cryptroot

# Check logs
journalctl -xe
```

### Hyprland Won't Start

```bash
# Switch to TTY: Ctrl+Alt+F2
# Login as C.Hessel

# Check Hyprland logs
cat ~/.local/share/hyprland/hyprland.log

# Check greetd
sudo journalctl -u greetd

# Try starting manually
Hyprland
```

### Network Issues

```bash
# Check NetworkManager
sudo systemctl status NetworkManager

# Restart
sudo systemctl restart NetworkManager

# Check connections
nmcli device status
nmcli connection show

# Connect to WiFi
nmtui
```

---

## 📊 Comparison: VM vs Production

| Feature | VM Testing | Production Laptop |
|---------|-----------|-------------------|
| **Installation** | Same process | Same process |
| **Speed** | Fast (native ARM) | Fast |
| **Disk** | `/dev/vda` | `/dev/nvme0n1` |
| **GPU** | Software rendering | Real GPU drivers |
| **Bluetooth** | No hardware | Real hardware |
| **WiFi** | Virtual ethernet | Real WiFi |
| **TPM2** | Usually no | Usually yes |
| **Battery** | N/A | Real battery |
| **Testing** | Safe, repeatable | Final validation |

**Recommendation:** Test in VM first, then deploy to production.

---

## 🎯 Quick Reference

### VM Testing
```bash
# 1. Start VM with NixOS ISO
# 2. In VM: sudo systemctl start sshd && sudo passwd
# 3. Get IP: ip addr show
# 4. On macOS:
cd ~/.config/nix-dotfiles
echo "test123" > /tmp/disko-password
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@VM_IP
```

### Production Laptop
```bash
# 1. Boot laptop from USB
# 2. Connect to WiFi
# 3. Enable SSH: sudo systemctl start sshd && sudo passwd
# 4. Get IP: ip addr show
# 5. On macOS:
cd ~/.config/nix-dotfiles
echo "YourStrongPassword" > /tmp/disko-password
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@LAPTOP_IP
```

---

## 🆘 Getting Help

**Resources:**
- nixos-anywhere docs: https://github.com/nix-community/nixos-anywhere
- NixOS manual: https://nixos.org/manual/nixos/stable/
- Hyprland wiki: https://wiki.hyprland.org/

**Check logs:**
```bash
journalctl -xe          # System logs
journalctl -u greetd    # Login manager
cat ~/.local/share/hyprland/hyprland.log  # Hyprland
```

---

**🎉 Enjoy your fully automated, declarative NixOS installation!**

The beauty of nixos-anywhere is you can reinstall anytime, and it's always identical.

