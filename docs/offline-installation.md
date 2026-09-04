# 📦 Offline Installation Guide (Closure Archive Method)

This guide explains how to pre-build and package the entire Flint NixOS system on a connected machine (e.g. via WSL or an existing Linux host) and install it on a target machine without requiring an active internet connection.

---

## 📋 Overview

NixOS builds a complete, hermetic dependency graph called a **System Closure**. By exporting this closure to a single `.nar` archive file, you capture 100% of all required dependencies (kernel, NVIDIA/AMD drivers, bootloader, desktop environment, CLI tools, and user configuration).

```
[ Connected Machine (WSL) ]
  1. Build System Closure (`nix build ...`)
  2. Export Closure (`nix-store --export ... > powerhouse-closure.nar`)
  3. Copy Flake Repository + `.nar` to USB Drive
       │
       ▼
[ USB Drive ]
  ├── powerhouse-closure.nar
  └── flint-nixos/
       │
       ▼
[ Target Machine (Offline Installation) ]
  1. Boot standard NixOS Minimal Live USB
  2. Partition & Mount disks to `/mnt`
  3. Mount USB Drive & Import Closure (`nix-store --import < ...`)
  4. Run `nixos-install --flake /path/to/flint-nixos#powerhouse --no-channel-copy`
  5. Reboot into the fully installed system
```

---

## 🛠️ Step-by-Step Instructions

### Phase 1: On the Host Machine (WSL / Connected Linux)

#### 1. Build the System Closure
Inside the `flint-nixos` directory, run:
```bash
nix build .#nixosConfigurations.powerhouse.config.system.build.toplevel
```
> This will download and compile all packages, creating a `./result` symlink in your directory.

#### 2. Export the Closure to USB
Plug in your USB drive. In WSL, external drives are mounted under `/mnt/d/`, `/mnt/e/`, etc.
```bash
# Export the complete closure to a single archive file on your USB drive
nix-store --export $(nix-store -qR ./result) > /mnt/d/powerhouse-closure.nar
```

#### 3. Copy the Configuration Repository to USB
Copy the `flint-nixos` configuration directory to the USB drive:
```bash
cp -r "/mnt/c/Users/kris/Documents/Misc Project/flint-nixos" /mnt/d/flint-nixos
```

---

### Phase 2: On the Target Machine (NixOS Live USB)

Boot the target PC with any standard NixOS Live USB. No network or Wi-Fi connection is needed.

#### 1. Partition and Format Disks
Set up your partitions (e.g., EFI boot and Root filesystem).

Example using `Btrfs`:
```bash
# Format partitions (Adjust disk identifiers according to `lsblk`)
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -f -L nixos /dev/nvme0n1p2

# Mount Root and Boot partitions
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

#### 2. Mount the Data USB Drive
Plug in the USB drive containing `powerhouse-closure.nar` and `flint-nixos`:
```bash
mkdir -p /mnt-usb
mount /dev/sdb1 /mnt-usb  # Check partition name with lsblk
```

#### 3. Import the Closure into the Target Nix Store
Import the `.nar` archive directly into the machine's local Nix store:
```bash
nix-store --import < /mnt-usb/powerhouse-closure.nar
```
> This will populate `/nix/store` with all required binaries at maximum USB read speed.

#### 4. Run the Installation
Install the system from the local flake on the USB:
```bash
nixos-install --flake /mnt-usb/flint-nixos#powerhouse --no-channel-copy
```
> `nixos-install` will detect that every derivation already exists in `/nix/store`, link the bootloader, generate system files, and prompt you to set the root password.

#### 5. Finish and Reboot
```bash
umount -R /mnt
reboot
```

---

## 🔍 Verification & Troubleshooting

- **Check Closure Integrity:**
  If you want to verify that the target Nix store has all required paths before running `nixos-install`:
  ```bash
  nix-store --verify --check-contents
  ```
- **Custom Hardware (`_hardware.nix`):**
  If the target machine has different disk UUIDs, generate the hardware configuration using `nixos-generate-config --root /mnt` and update `hosts/powerhouse/_hardware.nix` with the corresponding disk UUIDs/labels before building.
