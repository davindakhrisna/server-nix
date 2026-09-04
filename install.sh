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

# Select Disk if not specified
if [[ -z "$TARGET_DISK" ]]; then
    echo -e "${YELLOW}Detected storage drives on this machine:${NC}"
    echo "----------------------------------------------------"
    lsblk -d -p -n -o NAME,SIZE,TYPE,MODEL | grep -E "disk" || true
    echo "----------------------------------------------------"
    echo ""
    read -rp "Enter target disk to wipe and install to (e.g., /dev/nvme0n1 or /dev/sda): " TARGET_DISK
fi

if [[ ! -b "$TARGET_DISK" ]]; then
    echo -e "${RED}Error:${NC} Target device '$TARGET_DISK' does not exist or is not a block device!" >&2
    exit 1
fi

# Update disk device in hosts/$HOST_NAME/_disko.nix if needed
DISKO_FILE="hosts/$HOST_NAME/_disko.nix"
if [[ -f "$DISKO_FILE" ]]; then
    echo -e "${GREEN}==>${NC} Updating target disk in $DISKO_FILE to ${BOLD}$TARGET_DISK${NC}..."
    # Replace device = ... with device = lib.mkDefault "$TARGET_DISK";
    sed -i "s|device = lib.mkDefault \".*\";|device = lib.mkDefault \"$TARGET_DISK\";|" "$DISKO_FILE"
    git add "$DISKO_FILE" 2>/dev/null || true
fi

# Safety Confirmation
echo ""
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "${RED}${BOLD}       ⚠️  CRITICAL DATA LOSS WARNING ⚠️            ${NC}"
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "You are about to ${RED}${BOLD}COMPLETELY WIPE AND REPARTITION${NC}:"
echo -e "  Disk:       ${YELLOW}${BOLD}$TARGET_DISK${NC}"
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

# 1. Run Disko (Partition, Format, Mount)
echo -e "\n${GREEN}${BOLD}[1/3] Partitioning & Formatting disk with Disko...${NC}"
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    --flake ".#$HOST_NAME"

echo -e "\n${GREEN}✓ Partitions formatted and mounted to /mnt successfully.${NC}"

# 2. Run NixOS Install
echo -e "\n${GREEN}${BOLD}[2/3] Installing NixOS system closure to /mnt...${NC}"
nixos-install --flake ".#$HOST_NAME" --no-channel-copy

# 3. Post-install
echo -e "\n${GREEN}${BOLD}[3/3] Installation complete!${NC}"
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
