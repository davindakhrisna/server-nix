# 💾 Complete Installation & Deployment Guide

This guide covers installing and deploying the **NixOS Homelab Server** on bare-metal hardware (laptops, mini-PCs, workstations, or servers) as well as remote installations via `nixos-anywhere`.

---

## 📋 System Requirements & Hardware Support

| Component | Minimum | Recommended | Notes |
| :--- | :--- | :--- | :--- |
| **Architecture** | `x86_64-linux` | `x86_64-linux` | Tested on Intel & AMD CPUs |
| **RAM** | Depends on enabled services | 8+ GB | Swap reduces memory pressure; the full suite is not guaranteed on 2–4 GB |
| **Storage** | 32 GB | 256+ GB NVMe / SSD | Supports NVMe (`/dev/nvmeXn1`), SATA SSD/HDD (`/dev/sdX`), eMMC (`/dev/mmcblkX`), and VirtIO (`/dev/vdX`) |
| **Network** | Wi-Fi or Ethernet | Gigabit Ethernet | Tailscale peer-to-peer mesh enabled |
| **Form Factor** | Any | Old Laptop / Mini-PC | Lid switch ignore enabled for headless laptop operation |

---

## 🛡️ Low-RAM & Non-NVMe Protection

Standard NixOS installations on systems with low RAM ($\le 4\text{GB}$) or on live USBs frequently crash with **Out of Memory (OOM)** errors because:
1. Live ISOs store `/tmp` in RAM (`tmpfs`), filling physical memory during nix derivations.
2. Disko formats swap but does not activate it during the live installation session.
3. Nix parallel builds spawn too many jobs (`max-jobs`) and saturate memory.

**The [`install.sh`](../install.sh) script automates three layers of hardware protection:**
- 🔄 **Immediate Swap Activation (`swapon`):** The installer detects whether your drive is NVMe, SATA, eMMC, or virtual, and immediately activates the 8 GB swap partition before any package compilation begins.
- 📂 **Target Disk Temporary Directory (`TMPDIR=/mnt/tmp`):** Build artifacts and store paths are written to the target disk instead of the RAM `tmpfs`.
- ⚙️ **Dynamic Build Throttling:** On machines with $\le 6\text{GB}$ of physical RAM, the installer constrains compilation to `--option max-jobs 2 --option cores 2`.

---

## 🚀 Method 1: Local Automated Installation (Bare-Metal)

Use this method when booting the target server from a standard NixOS Minimal ISO USB drive.

### Step 1: Boot NixOS Minimal Live USB
1. Download the latest **NixOS Minimal ISO (x86_64)** from [nixos.org](https://nixos.org/download/).
2. Flash to a USB drive using [Etcher](https://etcher.balena.io/) or `dd`:
   ```bash
   sudo dd if=nixos-minimal.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```
3. Boot the target machine into the USB installer.

### Step 2: Connect to Network
- **Ethernet:** Automatically connects via DHCP.
- **Wi-Fi:** Connect using `nmtui` or `wpa_supplicant`:
  ```bash
  systemctl start NetworkManager
  nmtui
  ```

### Step 3: Clone Configuration
```bash
git clone <repository-url> /tmp/config
cd /tmp/config
```

Create the machine-local inventory before building. It is intentionally ignored
by Git:

```bash
cp hosts/homelab/_local.example.nix hosts/homelab/_local.nix
$EDITOR hosts/homelab/_local.nix
```

### Step 4: Identify Target Disk
Run `lsblk` to identify the destination drive:
```bash
lsblk
```
Common drive names:
- NVMe SSD: `/dev/nvme0n1`
- SATA SSD / HDD: `/dev/sda`
- eMMC Storage: `/dev/mmcblk0`

### Step 5: Run Installer
```bash
# Automated run with interactive disk confirmation
sudo ./install.sh --disk /dev/nvme0n1 --host homelab
```

The script will:
1. Display disk details and require explicit `yes` confirmation before formatting.
2. Partition the disk with Disko (ESP `/boot`, Swap, Btrfs subvolumes: `@`, `@home`, `@nix`, `@persist`, `@log`).
3. Activate swap immediately and route `TMPDIR` to disk.
4. Install NixOS to `/mnt`.
5. Copy the configuration repository into `/mnt/home/<user>/.config/config` (the username and ownership are read from the evaluated host configuration) and symlink `/etc/nixos` to it.
6. Provision missing service secrets into `/mnt/persist/secrets/` without displaying or overwriting them. Photo Gallery needs a real API key after creating your Immich account.
7. Prompt you to enter a password for the primary user via `nixos-enter`.
8. Prompt to reboot into your new installation.

---

## 🌐 Method 2: Remote Deployment over SSH (`nixos-anywhere`)

Deploy NixOS remotely onto an existing Linux server (e.g., Ubuntu, Debian, or generic VPS) without creating a live USB.

### Prerequisites
- Target machine accessible via SSH as `root` (or with passwordless `sudo`).
- Target machine running Linux with `kexec` support.

### Run Remote Installation:
From your local development machine:
```bash
./install.sh --mode remote --host homelab --target root@192.168.1.100 --disk /dev/sda
```

Remote mode requires an explicit `--disk`; it does not select the first drive.
The configuration workspace is copied through `--extra-files` and assigned to
the primary user. Missing service secrets are provisioned on first boot.
The remote user still needs a local password for ordinary sudo use; arrange
console access or an explicit initial password configuration before installing.

After either installation method, follow [Operations and migration](operations.md)
to enable Tailscale HTTPS, enroll NAS accounts, supply the Immich API key and
verify a backup restore. OpenHands is disabled on the main homelab host.

`nixos-anywhere` will kexec into a NixOS in-memory installer, partition the remote disk, install NixOS, and reboot into your configured server.

---

## 🔑 Post-Installation Setup (`post-install.sh`)

After the server reboots and you log in as the configured primary user:

```bash
cd ~/.config/config
./post-install.sh
```

This interactive helper completes:
1. **GitHub 24/7 Deploy Key:** Generates a dedicated Ed25519 key (`~/.ssh/id_github_deploy`) and displays the public key to paste into GitHub (**Settings -> Deploy Keys -> Allow write access**).
2. **SSH Remote Configuration:** Automatically tests GitHub SSH authentication and converts the git remote from HTTPS to SSH.
3. **Tailscale & Tailscale SSH:** Verifies Tailscale status and runs `sudo tailscale up --ssh` to enable instant zero-trust remote access.

---

## 💻 Headless Laptop Operation

If your server is a repurposed laptop:
- **Lid Close:** Closing the lid will **not** suspend or shut down the machine. The server configures:
  ```nix
  services.logind.settings = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
  ```
- **Sleep Suppression:** `systemd.targets.sleep.enable = false;` and `suspend.enable = false;` ensure the system stays online 24/7.

---

## 🔄 Day-2 Operations & System Rebuilds

Once installed, manage your system with **Nix Helper (`nh`)**:

```bash
# Rebuild and switch system configuration
nh os switch

# Test configuration without setting as boot default
nh os test

# List previous generations and roll back
nh os rollback

# Clean old Nix store paths and generations
nh clean all --keep 5
```
