# Farnsworth VM Testing Guide (UTM + nixos-anywhere)

Quick guide to test the farnsworth NixOS configuration in a VM using **nixos-anywhere** - the modern, automated installation method.

**Why nixos-anywhere?**
- ✅ Fully automated from macOS
- ✅ No manual commands in VM
- ✅ Same process as production deployment
- ✅ Fast and repeatable
- ✅ Easy to test config changes

---

## 🚀 Quick Start (5 Minutes)

### 1. Run Setup Script

```bash
cd ~/.config/nix-dotfiles
./vm-test-setup.sh
```

This downloads the NixOS ISO and prepares everything.

### 2. Create UTM VM

1. Open UTM
2. Create New VM → **Virtualize** → Linux
3. Use downloaded ISO: `~/Downloads/nixos-minimal-aarch64-linux.iso`
4. Config: **8GB RAM, 4 cores, 64GB storage**
5. Name: **farnsworth-test**

### 3. Boot VM and Enable SSH

```bash
# In VM console (login as: nixos, no password)
sudo systemctl start sshd
sudo passwd  # Set password: test123
ip addr show  # Note the IP (e.g., 192.168.64.5)
```

### 4. Install from macOS

```bash
# On macOS
cd ~/.config/nix-dotfiles
echo "test123" > /tmp/disko-password

nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@192.168.64.5  # Use your VM's IP
```

**Done!** System installs automatically (15-20 min), reboots, ready to test.

---

## 📋 Detailed Prerequisites

### 1. Install UTM

**Option A: Via Homebrew** (Recommended)
```bash
brew install --cask utm
```

**Option B: Direct Download**
- Download from: https://mac.getutm.app/
- Or App Store: https://apps.apple.com/app/utm-virtual-machines/id1538878817

### 2. Prepare Installation

The `vm-test-setup.sh` script handles:
- ✅ Downloading NixOS ISO (ARM or x86_64)
- ✅ Checking UTM installation
- ✅ Providing next steps

**Recommended:** ARM ISO for Apple Silicon (much faster than x86_64 emulation).

---

## 🖥️ Part 1: Create and Boot UTM VM

### 1. Create VM in UTM

1. **Open UTM** → **"Create a New Virtual Machine"**
2. **Choose "Virtualize"** (faster on Apple Silicon)
3. **Operating System**: **"Linux"**
4. **Boot ISO**: Select downloaded ISO (`~/Downloads/nixos-minimal-aarch64-linux.iso`)
5. **Hardware**:
   - Memory: **8192 MB** (8 GB)
   - CPU: **4 cores**
   - Storage: **64 GB**
6. **Name**: **"farnsworth-test"**
7. **Save**

### 2. Start VM and Enable SSH

**Boot the VM:**
- Click **▶ Play** button
- Wait for login prompt

**In VM console:**
```bash
# Login (username: nixos, no password)

# Start SSH server
sudo systemctl start sshd

# Set root password for SSH
sudo passwd
# Enter: test123

# Get VM IP address
ip addr show
# Look for: 192.168.64.X (or similar)
# Note this IP!
```

**Test SSH from macOS:**
```bash
ssh root@192.168.64.X
# Enter password: test123
# Should connect successfully
exit
```

---

## 💾 Part 2: Install with nixos-anywhere

### From macOS Terminal

```bash
# Navigate to dotfiles
cd ~/.config/nix-dotfiles

# Create encryption password file
echo "test123" > /tmp/disko-password
chmod 600 /tmp/disko-password

# Run nixos-anywhere (replace IP with your VM's IP)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#farnsworth \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  root@192.168.64.5

# Enter SSH password when prompted: test123
```

### What Happens

nixos-anywhere will:
1. ✅ Connect to VM via SSH
2. ✅ Partition disk (`/dev/vda`)
3. ✅ Setup LUKS encryption
4. ✅ Create Btrfs subvolumes
5. ✅ Install NixOS with your config
6. ✅ Install all packages (Hyprland, Waybar, etc.)
7. ✅ Configure everything
8. ✅ Reboot

**Time:** 15-20 minutes

**You can watch progress** in the terminal output.

---

## 🧪 Part 5: Test Installation

### 1. Boot into Farnsworth

1. VM will reboot
2. **Disk encryption prompt** appears: Enter `test123` (or your password)
3. **greetd login** appears

### 2. Login

```
Username: C.Hessel
Password: (the password you set)
```

### 3. Test Hyprland

Hyprland should start automatically after login.

**Key Bindings to Test:**
- `SUPER + RETURN` - Open terminal (WezTerm)
- `SUPER + D` - App launcher (rofi)
- `SUPER + Q` - Close window
- `SUPER + 1-9` - Switch workspaces
- `SUPER + H/J/K/L` - Navigate windows

### 4. Test Basic Functionality

```bash
# In WezTerm terminal

# Test Fish shell
fish --version

# Test Nix
nix --version

# Test internet
ping -c 3 nixos.org

# Test Docker
sudo systemctl status docker

# Test Btrfs
btrfs-status

# Check filesystem
df -h

# Check encryption
lsblk
```

### 5. Test Waybar

- Should see status bar at top
- Check: workspaces, CPU, RAM, network icon
- Clock should show time

### 6. Test Package Installation

```bash
# Try installing a package
nix-shell -p htop
htop  # Should work
exit
```

### 7. Test Configuration Changes

```bash
cd ~/.config/nix-dotfiles

# Make a small change (e.g., add a package)
vim hosts/farnsworth/default.nix
# Add 'neofetch' to environment.systemPackages

# Rebuild
sudo nixos-rebuild switch --flake .#farnsworth

# Test
neofetch
```

### 8. Test Impermanence (Optional but Important)

```bash
# Create a file in root
sudo touch /test-file

# Reboot
sudo reboot

# After reboot, check if file is gone
ls /test-file  # Should not exist

# Check persistent directories
ls /persist
ls /home/C.Hessel  # Should still have your files
```

---

## 🐛 Troubleshooting

### VM Won't Boot After Installation

**Symptom:** Stuck at UEFI shell or boot error

**Fix:**
1. In UTM, go to VM settings
2. **Boot Order**: Ensure disk (not CD) is first
3. Remove the ISO from CD drive
4. Restart VM

### Hyprland Won't Start

**Symptom:** Black screen or login loop

**Check:**
```bash
# Switch to TTY (Ctrl+Alt+F2 in UTM)
# Login as C.Hessel

# Check Hyprland logs
journalctl -u greetd -b

# Try starting Hyprland manually
Hyprland
```

**Common causes:**
- GPU driver issue (should auto-use software rendering in VM)
- Missing packages

### Disk Space Issues

**Symptom:** "No space left on device"

**Check Btrfs balance:**
```bash
btrfs-status
sudo btrfs balance start -dusage=50 /
```

### Network Not Working

```bash
# Check NetworkManager
sudo systemctl status NetworkManager

# Restart if needed
sudo systemctl restart NetworkManager

# Check connection
nmcli device status
nmcli connection show
```

### Slow Performance (x86_64 VM)

This is expected due to emulation. Solutions:
- Test on ARM VM instead (native speed)
- Allocate more CPU cores in UTM settings
- Enable KVM if available (usually not on macOS)

---

## 📝 Testing Checklist

Use this checklist to validate the installation:

### System
- [ ] VM boots successfully
- [ ] LUKS encryption works (password prompt)
- [ ] greetd login works
- [ ] Hyprland starts

### Desktop
- [ ] Waybar displays correctly
- [ ] Terminal opens (SUPER+RETURN)
- [ ] App launcher works (SUPER+D)
- [ ] Workspaces switch (SUPER+1-9)
- [ ] Window management (SUPER+H/J/K/L)

### Services
- [ ] NetworkManager active (internet works)
- [ ] Docker running
- [ ] SSH server active (if testing remote)
- [ ] PipeWire audio (test with `speaker-test`)

### Filesystem
- [ ] Btrfs mounted correctly
- [ ] Compression working (`compsize /`)
- [ ] Impermanence working (files in / disappear after reboot)
- [ ] Persist directories survive reboot

### Packages
- [ ] Fish shell works
- [ ] Neovim launches
- [ ] Git works
- [ ] Development tools available

### Configuration
- [ ] Can rebuild system (`nixos-rebuild switch`)
- [ ] Changes persist after rebuild
- [ ] Rollback works

---

## 🎯 Next Steps After Successful Test

Once everything works in the VM:

1. **Document any issues** you found and fix them in the config
2. **Commit improvements** to your dotfiles
3. **Create installation media** for real hardware
4. **Deploy to actual laptop** following `FARNSWORTH_INSTALLATION.md`

### Differences Between VM and Real Hardware

**In VM (testing):**
- Virtual disk (`/dev/vda`)
- No real GPU (software rendering)
- No Bluetooth/WiFi hardware
- No TPM2 (encryption passphrase only)

**On Real Hardware:**
- Real disk (`/dev/nvme0n1` or `/dev/sda`)
- Real GPU (NVIDIA/AMD drivers may be needed)
- Real Bluetooth/WiFi
- TPM2 available for auto-unlock

**Remember to adjust `hosts/farnsworth/disko.nix` disk device path for real hardware!**

---

## 💡 Tips

1. **Snapshot the VM** after successful installation (UTM has snapshot feature)
2. **Test configuration changes** in VM before applying to real hardware
3. **Use ARM VM** for faster testing on Apple Silicon
4. **Keep VM around** for testing future updates
5. **Document issues** you find for the installation guide

---

## 🆘 Getting Help

If you encounter issues:

1. Check `journalctl -xe` for system errors
2. Review Hyprland logs: `~/.local/share/hyprland/hyprland.log`
3. Test in minimal config first (disable Waybar, etc.)
4. Compare with working macOS config for patterns

---

**Happy Testing! 🚀**

Once the VM test is successful, you can confidently deploy to real hardware.

