# 📦 Offline Installation Guide (Closure Archive Method)

This guide explains how to pre-build and package the entire Flint NixOS system on a connected machine (e.g. via WSL or an existing Linux host) and install it on your target homelab machine without requiring an active internet connection.

---

## 📋 Overview

NixOS builds a complete, hermetic dependency graph called a **System Closure**. By exporting this closure to a single `.nar` archive file, you capture 100% of all required dependencies (kernel, CPU/GPU drivers, bootloader, CLI tools, homelab services, user environment, and Disko disk management tools).

```
[ Connected Machine (WSL) ]
  1. Build System Closure (`nix build ...#homelab...`)
  2. Export Closure (`nix-store --export ... > homelab-closure.nar`)
  3. Copy Repository + `.nar` to USB Drive
       │
       ▼
[ USB Drive ]
  ├── homelab-closure.nar
  └── server-nixos/
       │
       ▼
[ Target Machine (Offline Installation) ]
  1. Boot standard NixOS Minimal Live USB
  2. Mount USB Drive (`mount /dev/sdb1 /mnt-usb`)
  3. Import Closure into local Nix Store (`nix-store --import < ...`)
  4. Run automated installer:
     `sudo /mnt-usb/server-nixos/install.sh --disk /dev/nvme0n1 --host homelab`
  5. Reboot into the fully installed system
```

---

## 🛠️ Step-by-Step Instructions

### Phase 1: On the Connected Machine (WSL / Linux)

#### 1. Build the System Closure
Inside the `server-nixos` directory, build the top-level closure for `homelab`:

```bash
nix build .#nixosConfigurations.homelab.config.system.build.toplevel
```
> This downloads and compiles all derivations, placing a `./result` symlink in your directory.

#### 2. Export the Closure to Your USB Drive
Plug in your external USB drive (in WSL, external drives are mounted at `/mnt/d/`, `/mnt/e/`, etc.):

```bash
# Export the complete closure to a single archive file on your USB drive
nix-store --export $(nix-store -qR ./result) > /mnt/d/homelab-closure.nar
```

#### 3. Copy the Configuration Repository to the USB Drive
Copy the `server-nixos` configuration directory onto the USB drive:

```bash
cp -r "/mnt/c/Users/kris/Documents/Misc Project/server-nixos" /mnt/d/server-nixos
```

---

### Phase 2: On the Target Machine (NixOS Live USB)

Boot the target homelab PC using any standard NixOS Minimal Live USB. No network or Wi-Fi connection is required.

#### 1. Mount the Data USB Drive
Plug in the USB drive containing `homelab-closure.nar` and `server-nixos`. Identify its partition using `lsblk`:

```bash
mkdir -p /mnt-usb
mount /dev/sdb1 /mnt-usb  # Adjust device identifier according to lsblk
```

#### 2. Import the Closure into the Target Nix Store
Import the `.nar` archive directly into the local Nix store:

```bash
nix-store --import < /mnt-usb/homelab-closure.nar
```
> This populates `/nix/store` with 100% of your system dependencies at maximum USB read speed.

#### 3. Partition, Format, and Install

You have two ways to partition and install:

##### Method A: Fully Automated via `install.sh` (Recommended)
Run the provided installer directly from the USB drive:

```bash
cd /mnt-usb/server-nixos
sudo ./install.sh --disk /dev/nvme0n1 --host homelab
```
*(Or run `sudo ./install.sh` without arguments to choose the disk interactively from a detected drive list).*

The script will:
1. Prompt you with a safety confirmation before wiping.
2. Execute **Disko** to wipe, partition, and format the drive (1G ESP `/boot`, 8G Swap, and Btrfs subvolumes `@`, `@home`, `@nix`, `@persist`, `@log`).
3. Mount everything under `/mnt`.
4. Run `nixos-install --flake .#homelab --no-channel-copy`.
5. Prompt you to set your root password.

##### Method B: Manual Disko Execution
If you prefer running the commands step-by-step:

```bash
# 1. Partition and mount with Disko
nix --extra-experimental-features "nix-command flakes" run /mnt-usb/server-nixos#disko -- \
  --mode disko \
  --flake /mnt-usb/server-nixos#homelab

# 2. Install NixOS from the USB repository
nixos-install --flake /mnt-usb/server-nixos#homelab --no-channel-copy
```

#### 4. Finish and Reboot
```bash
umount -R /mnt 2>/dev/null || true
reboot
```

---

## 🔍 Verification & Troubleshooting

- **Check Closure Integrity:**
  Verify that all paths are present before running the install:
  ```bash
  nix-store --verify --check-contents
  ```
- **Custom Disk Device:**
  If your target machine uses a SATA SSD (`/dev/sda`) instead of an NVMe SSD (`/dev/nvme0n1`), pass `--disk /dev/sda` to `install.sh`, or update the `device` attribute in `hosts/homelab/_disko.nix` before building the closure.
- **Hardware Drivers (`_hardware.nix`):**
  Disko handles all filesystems and swap partitions automatically. `hosts/homelab/_hardware.nix` only manages kernel modules (`xhci_pci`, `ahci`, `nvme`, `kvm-intel`, etc.). If your homelab uses an AMD CPU, set `kernelModules = ["kvm-amd"];` and `var.cpu = "amd";`.
