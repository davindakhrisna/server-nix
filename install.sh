#!/usr/bin/env bash
# ==============================================================================
# Flint NixOS Automated Installer (Disko + Nix Flakes)
# ==============================================================================
# Automates disk partitioning, formatting, and NixOS system installation.
# Supports both Local (Live USB) and Remote (nixos-anywhere over SSH) modes.
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Defaults
MODE="local"
HOST_NAME="homelab"
TARGET_DISK=""
REMOTE_TARGET=""
SKIP_CONFIRM=false

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]

${BOLD}Options:${NC}
  -m, --mode <local|remote>   Installation mode (default: local)
                              'local':  Run directly from NixOS Live USB on target machine.
                              'remote': Install remotely over SSH to Ubuntu/Debian using nixos-anywhere.
  -H, --host <hostname>       NixOS host configuration to install (default: homelab)
  -d, --disk <device>         Target disk (e.g., /dev/nvme0n1, /dev/sda, or /dev/disk/by-id/...)
  -t, --target <user@ip>      Remote SSH target (required for remote mode, e.g. root@192.168.1.50)
  -y, --yes                   Skip confirmation prompt (DANGEROUS: Wipes disk unattended)
  -h, --help                  Show this help message

${BOLD}Examples:${NC}
  # 1. Interactive local install from Live USB:
  sudo ./install.sh

  # 2. Local install specifying disk and host:
  sudo ./install.sh --disk /dev/nvme0n1 --host homelab

  # 3. Remote install directly over running Ubuntu server via SSH:
  ./install.sh --mode remote --host homelab --target root@192.168.1.100"
    exit 0
}

# Parse CLI Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -H|--host)
            HOST_NAME="$2"
            shift 2
            ;;
        -d|--disk)
            TARGET_DISK="$2"
            shift 2
            ;;
        -t|--target)
            REMOTE_TARGET="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Ensure we're in the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${BLUE}${BOLD}   ❄️  Flint NixOS Automated Installer (Disko)      ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Verify Host Directory Exists
if [[ ! -d "hosts/$HOST_NAME" ]]; then
    echo -e "${RED}Error:${NC} Host configuration 'hosts/$HOST_NAME' not found!" >&2
    echo "Available hosts:"
    ls -1 hosts | sed 's/^/  - /'
    exit 1
fi

# ==============================================================================
# MODE: REMOTE (nixos-anywhere)
# ==============================================================================
if [[ "$MODE" == "remote" ]]; then
    if [[ -z "$REMOTE_TARGET" ]]; then
        echo -e "${RED}Error:${NC} Remote mode requires --target <user@ip> (e.g. root@192.168.1.50)" >&2
        exit 1
    fi

    echo -e "${YELLOW}Mode:${NC} Remote install via nixos-anywhere"
    echo -e "${YELLOW}Target:${NC} $REMOTE_TARGET"
    echo -e "${YELLOW}Host Configuration:${NC} $HOST_NAME"
    echo ""

    if [[ "$SKIP_CONFIRM" != true ]]; then
        echo -e "${RED}${BOLD}⚠️  DANGER / PERMANENT DATA LOSS WARNING ⚠️${NC}"
        echo -e "This will connect to ${BOLD}$REMOTE_TARGET${NC}, bootstrap a NixOS live environment in RAM,"
        echo -e "and ${RED}${BOLD}PERMANENTLY WIPE${NC} its primary storage drive using Disko."
        echo ""
        read -rp "Are you absolutely sure you want to proceed? Type 'YES': " CONFIRM
        if [[ "$CONFIRM" != "YES" ]]; then
            echo "Installation aborted."
            exit 1
        fi
    fi

    echo -e "\n${GREEN}==>${NC} Running nixos-anywhere..."
    nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
        --flake ".#$HOST_NAME" \
        "$REMOTE_TARGET"

    echo -e "\n${GREEN}${BOLD}✓ Remote installation completed successfully!${NC}"
    echo "The remote machine should be rebooting into NixOS."
    exit 0
fi

# ==============================================================================
# MODE: LOCAL (Live USB)
# ==============================================================================
# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error:${NC} Local installation must be run as root (or with sudo)." >&2
   exit 1
fi

# 0. Live ISO Environment Memory Expansion (Prevent "No space left on device")
echo -e "${CYAN}${BOLD}[0/3] Optimizing Live ISO temporary filesystems...${NC}"

# Expand in-memory Nix store quota (default is only 50% of RAM, often 1-2GB)
if grep -qs '/nix/.rw-store' /proc/mounts; then
    echo -e "  ${GREEN}==>${NC} Expanding in-memory /nix/.rw-store to 16GB..."
    mount -o remount,size=16G,noatime /nix/.rw-store 2>/dev/null || true
fi

# Expand /tmp quota if mounted on tmpfs
if grep -qs ' /tmp tmpfs' /proc/mounts; then
    mount -o remount,size=8G /tmp 2>/dev/null || true
fi

# Activate any existing swap partitions available across all drives
for existing_swap in $(lsblk -ln -o NAME,FSTYPE 2>/dev/null | awk '$2=="swap" {print "/dev/"$1}'); do
    if swapon "$existing_swap" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Enabled existing swap on ${BOLD}${existing_swap}${NC} for extra memory headroom"
    fi
done

# Select Disk if not specified
if [[ -z "$TARGET_DISK" ]]; then
    echo -e "\n${YELLOW}Detected storage drives on this machine:${NC}"
    echo "----------------------------------------------------------------------"
    lsblk -p -o NAME,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS | grep -E "(NAME|disk)" || true
    echo "----------------------------------------------------------------------"
    echo ""
    read -rp "Enter target disk to wipe and install to (e.g., /dev/nvme0n1 or /dev/sda): " TARGET_DISK
fi

if [[ ! -b "$TARGET_DISK" ]]; then
    echo -e "${RED}Error:${NC} Target device '$TARGET_DISK' does not exist or is not a block device!" >&2
    exit 1
fi

# Safety Guard: Ensure user is NOT wiping the running Live USB installer drive
if lsblk -no FSTYPE,LABEL,MOUNTPOINTS "$TARGET_DISK" 2>/dev/null | grep -E "(iso9660|NIXOS|/iso|/cdrom|/run/iso)" >/dev/null 2>&1; then
    echo -e "\n${RED}${BOLD}========================================================================${NC}"
    echo -e "${RED}${BOLD}❌ ERROR: CANNOT INSTALL TO LIVE INSTALLER MEDIA (${TARGET_DISK})!${NC}"
    echo -e "${RED}${BOLD}========================================================================${NC}"
    echo -e "${YELLOW}'$TARGET_DISK' appears to be the NixOS Live USB flash drive you booted from!${NC}"
    echo -e "Installing to this device will destroy the installer and cause 'No space left on device'."
    echo ""
    echo -e "Please check all available drives below and choose your actual internal SSD/HDD:"
    echo "----------------------------------------------------------------------"
    lsblk -p -o NAME,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS
    echo "----------------------------------------------------------------------"
    exit 1
fi

# Check drive capacity
DISK_SIZE_BYTES=$(lsblk -b -d -n -o SIZE "$TARGET_DISK" 2>/dev/null || echo 0)
DISK_SIZE_GB=$(( DISK_SIZE_BYTES / 1024 / 1024 / 1024 ))
if [ "$DISK_SIZE_GB" -lt 20 ] && [ "$DISK_SIZE_GB" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  Warning: Target disk '$TARGET_DISK' is only ${DISK_SIZE_GB}GB.${NC}"
    echo -e "Disko partitions 1GB for ESP and 8GB for swap, leaving ~$(( DISK_SIZE_GB - 9 ))GB for root."
fi

# Update disk device in hosts/$HOST_NAME/_disko.nix if needed
DISKO_FILE="hosts/$HOST_NAME/_disko.nix"
if [[ -f "$DISKO_FILE" ]]; then
    echo -e "\n${GREEN}==>${NC} Updating target disk in $DISKO_FILE to ${BOLD}$TARGET_DISK${NC}..."
    sed -i "s|device = lib.mkDefault \".*\";|device = lib.mkDefault \"$TARGET_DISK\";|" "$DISKO_FILE"
    git add "$DISKO_FILE" 2>/dev/null || true
fi

# Safety Confirmation
echo ""
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "${RED}${BOLD}       ⚠️  CRITICAL DATA LOSS WARNING ⚠️            ${NC}"
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "You are about to ${RED}${BOLD}COMPLETELY WIPE AND REPARTITION${NC}:"
echo -e "  Disk:        ${YELLOW}${BOLD}$TARGET_DISK${NC} (${DISK_SIZE_GB} GB)"
echo -e "  Host Config: ${YELLOW}${BOLD}$HOST_NAME${NC}"
echo ""
echo -e "All existing partitions and data on ${BOLD}$TARGET_DISK${NC} will be permanently erased."
echo ""

if [[ "$SKIP_CONFIRM" != true ]]; then
    read -rp "Type 'YES' in all caps to proceed with the wipe: " CONFIRM
    if [[ "$CONFIRM" != "YES" ]]; then
        echo -e "${YELLOW}Installation cancelled by user.${NC}"
        exit 1
    fi
fi

# Ensure any active swap or mounts on target disk are released before partitioning
for part in $(lsblk -ln -o NAME "$TARGET_DISK" 2>/dev/null | awk '{print "/dev/"$1}'); do
    swapoff "$part" 2>/dev/null || true
    umount -l "$part" 2>/dev/null || true
done

# 1. Run Disko (Partition, Format, Mount using standalone disko config to prevent OOM)
echo -e "\n${GREEN}${BOLD}[1/3] Partitioning & Formatting disk with Disko...${NC}"
nix --extra-experimental-features "nix-command flakes" run nixpkgs#disko -- \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    "$DISKO_FILE"

echo -e "\n${GREEN}✓ Partitions formatted and mounted to /mnt successfully.${NC}"

# Settle udev events to ensure new partition device nodes exist
udevadm settle 2>/dev/null || sleep 2

# 1.5 Memory Protection (Prevent OOM & "No space left on device" during closure build)
echo -e "\n${GREEN}==>${NC} Configuring storage & memory protection..."

# Activate the 8GB swap partition created on the target disk by Disko
SWAP_ACTIVATED=false
for part in $(lsblk -ln -o NAME,FSTYPE "$TARGET_DISK" 2>/dev/null | awk '$2=="swap" {print "/dev/"$1}'); do
    if swapon "$part" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Activated swap on ${BOLD}${part}${NC} (prevents Out-Of-Memory)"
        SWAP_ACTIVATED=true
        break
    fi
done

# If swap partition was not automatically detected, try formatting and activating partition 2
if [[ "$SWAP_ACTIVATED" != true ]]; then
    # In MBR/GPT, partition 2 is swap in our layout (e.g. /dev/sda2 or /dev/nvme0n1p2)
    for candidate in "${TARGET_DISK}2" "${TARGET_DISK}p2"; do
        if [[ -b "$candidate" ]]; then
            mkswap -f "$candidate" >/dev/null 2>&1 || true
            if swapon "$candidate" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Activated swap on ${BOLD}${candidate}${NC}"
                SWAP_ACTIVATED=true
                break
            fi
        fi
    done
fi

# Further expand /nix/.rw-store now that 8GB disk swap is active
if grep -qs '/nix/.rw-store' /proc/mounts; then
    echo -e "  ${GREEN}==>${NC} Expanding /nix/.rw-store to 32GB (backed by disk swap)..."
    mount -o remount,size=32G,noatime /nix/.rw-store 2>/dev/null || true
fi

# Relocate build TMPDIR to target disk instead of RAM-backed tmpfs
mkdir -p /mnt/tmp
chmod 1777 /mnt/tmp
export TMPDIR=/mnt/tmp
echo -e "  ${GREEN}✓ Relocated build TMPDIR to target storage (/mnt/tmp)${NC} (saves RAM)"

# Detect available RAM and constrain parallel jobs if <= 6GB
MEM_TOTAL_KB=$(grep -i MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 8000000)
MEM_TOTAL_GB=$(( MEM_TOTAL_KB / 1024 / 1024 ))
EXTRA_INSTALL_ARGS=()
if [ "$MEM_TOTAL_GB" -le 6 ]; then
    echo -e "  ${YELLOW}Detected physical RAM <= 6GB (${MEM_TOTAL_GB}GB). Limiting build jobs...${NC}"
    EXTRA_INSTALL_ARGS+=(--option max-jobs 2 --option cores 2)
fi

# Display current memory & mount state for transparency
echo -e "\n${BLUE}--- Storage & Memory Status ---${NC}"
free -h 2>/dev/null | grep -E "(Mem|Swap)" || true
df -h /mnt /mnt/boot /nix/.rw-store 2>/dev/null || true
echo -e "${BLUE}-------------------------------${NC}"

# 2. Run NixOS Install
echo -e "\n${GREEN}${BOLD}[2/3] Installing NixOS system closure to /mnt...${NC}"
nixos-install --flake ".#$HOST_NAME" --no-channel-copy "${EXTRA_INSTALL_ARGS[@]}"

# 2.5 Post-Install System Configuration
echo -e "\n${GREEN}==>${NC} Setting up user workspace & configuration repository..."

# Copy configuration repository to /home/kryisnn/.config/flint
mkdir -p /mnt/home/kryisnn/.config/flint
cp -r . /mnt/home/kryisnn/.config/flint/
chown -R 1000:100 /mnt/home/kryisnn/.config/flint
mkdir -p /mnt/etc
ln -sfn /home/kryisnn/.config/flint /mnt/etc/nixos
echo -e "  ${GREEN}✓ Configuration copied to /home/kryisnn/.config/flint (linked to /etc/nixos)${NC}"

# Prompt to set password for primary user kryisnn (sudo access)
echo -e "\n${GREEN}==>${NC} Set login & sudo password for primary user ${BOLD}kryisnn${NC}:"
nixos-enter --root /mnt -c "passwd kryisnn" || true

# Cleanup temporary installation swap & files
swapoff -a 2>/dev/null || true
[ -f /mnt/swapfile ] && rm -f /mnt/swapfile
rm -rf /mnt/tmp

# 3. Post-install
echo -e "\n${GREEN}${BOLD}[3/3] Installation complete!${NC}"
echo ""
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ Flint NixOS Successfully Installed!            ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "Next steps on first boot:"
echo -e "  1. Log in as ${BOLD}kryisnn${NC}"
echo -e "  2. Run: ${CYAN}cd ~/.config/flint && ./post-install.sh${NC}"
echo -e "     (Sets up your 24/7 GitHub Deploy Key and Tailscale)"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""
read -rp "Would you like to unmount /mnt and reboot now? [y/N]: " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    echo "Unmounting filesystems..."
    umount -R /mnt 2>/dev/null || true
    echo "Rebooting..."
    reboot
else
    echo "You can manually reboot when ready with: umount -R /mnt && reboot"
fi
