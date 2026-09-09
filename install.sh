#!/usr/bin/env bash
# ==============================================================================
# NixOS Server Automated Installer (Disko + Nix Flakes)
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
DIM='\033[2m'
NC='\033[0m' # No Color

# Defaults
MODE="local"
HOST_NAME="homelab"
TARGET_DISK=""
REMOTE_TARGET=""
CACHE_PATH=""
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
  -c, --cache <path>          Path to pre-built nix binary cache (e.g., /mnt-usb/nix-cache)
                              Auto-detected from USB if not specified.
  -y, --yes                   Skip confirmation prompt (DANGEROUS: Wipes disk unattended)
  -h, --help                  Show this help message

${BOLD}Examples:${NC}
  # 1. Interactive local install from Live USB:
  sudo ./install.sh

  # 2. Local install specifying disk and host:
  sudo ./install.sh --disk /dev/nvme0n1 --host homelab

  # 3. Remote install directly over running Ubuntu server via SSH:
  ./install.sh --mode remote --host homelab --target root@192.168.1.100

  # 4. Local install with pre-built cache from USB (zero compilation):
  sudo ./install.sh --cache /mnt-usb/nix-cache"
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
        -c|--cache)
            CACHE_PATH="$2"
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
echo -e "${BLUE}${BOLD}   ❄️  NixOS Server Automated Installer (Disko)      ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Verify Host Directory Exists
if [[ ! -d "hosts/$HOST_NAME" ]]; then
    echo -e "${RED}Error:${NC} Host configuration 'hosts/$HOST_NAME' not found!" >&2
    echo "Available hosts:"
    ls -1 hosts | sed 's/^/  - /'
    exit 1
fi

# Derive primary username from the host configuration (users.users.<name>)
USER_NAME=$(grep -oP 'users\.users\.\K[a-zA-Z0-9_-]+(?=\s*=\s*\{)' "hosts/$HOST_NAME/default.nix" 2>/dev/null | head -1)
if [[ -z "$USER_NAME" ]]; then
    echo -e "${RED}Error:${NC} Could not detect primary user in hosts/$HOST_NAME/default.nix" >&2
    echo "Define it as: users.users.<username> = { ... }" >&2
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

    # Auto-detect remote disk if not provided
    DISKO_FILE="hosts/$HOST_NAME/_disko.nix"
    if [[ -z "$TARGET_DISK" ]]; then
        REMOTE_DETECTED_DISK=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_TARGET" \
            "lsblk -dpno NAME,TYPE 2>/dev/null | awk '\$2==\"disk\" {print \$1; exit}'" 2>/dev/null || true)
        if [[ -n "$REMOTE_DETECTED_DISK" ]]; then
            TARGET_DISK="$REMOTE_DETECTED_DISK"
            echo -e "  ${GREEN}==>${NC} Auto-detected remote primary disk: ${BOLD}$TARGET_DISK${NC}"
        fi
    fi

    # Update disk device in hosts/$HOST_NAME/_disko.nix
    if [[ -n "$TARGET_DISK" && -f "$DISKO_FILE" ]]; then
        echo -e "${YELLOW}Target Disk:${NC} $TARGET_DISK"
        echo -e "  ${GREEN}==>${NC} Updating target disk in $DISKO_FILE to ${BOLD}$TARGET_DISK${NC}..."
        sed -i "s|device = lib.mkDefault \".*\";|device = lib.mkDefault \"$TARGET_DISK\";|" "$DISKO_FILE"
        git add "$DISKO_FILE" 2>/dev/null || true
    fi

    # Detect remote CPU architecture (Intel vs AMD)
    HOST_DEFAULT="hosts/$HOST_NAME/default.nix"
    if [[ -f "$HOST_DEFAULT" ]]; then
        REMOTE_CPU_INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_TARGET" "cat /proc/cpuinfo 2>/dev/null" || true)
        if [[ -n "$REMOTE_CPU_INFO" ]]; then
            DETECTED_CPU="intel"
            if echo "$REMOTE_CPU_INFO" | grep -q "AuthenticAMD"; then
                DETECTED_CPU="amd"
            elif echo "$REMOTE_CPU_INFO" | grep -q "GenuineIntel"; then
                DETECTED_CPU="intel"
            fi
            echo -e "  ${GREEN}==>${NC} Detected remote CPU architecture: ${BOLD}${DETECTED_CPU}${NC}"
            sed -i "s|cpu = \".*\";|cpu = \"$DETECTED_CPU\";|" "$HOST_DEFAULT"
            git add "$HOST_DEFAULT" 2>/dev/null || true
        fi
    fi
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

# Detect and configure target CPU architecture (Intel vs AMD)
HOST_DEFAULT="hosts/$HOST_NAME/default.nix"
if [[ -f "$HOST_DEFAULT" ]]; then
    DETECTED_CPU="intel"
    if grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        DETECTED_CPU="amd"
    elif grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        DETECTED_CPU="intel"
    fi
    echo -e "  ${GREEN}==>${NC} Detected target CPU architecture: ${BOLD}${DETECTED_CPU}${NC}"
    sed -i "s|cpu = \".*\";|cpu = \"$DETECTED_CPU\";|" "$HOST_DEFAULT"
    git add "$HOST_DEFAULT" 2>/dev/null || true
fi

# 0.7 Detect or validate pre-built binary cache from USB (BEFORE disk wipe)
CACHE_SUBSTITUTERS=""
CACHE_INSTALL_ARGS=()
CACHE_NAR_COUNT="0"

# Guard: If USB was mounted under /mnt (e.g. /mnt/usb), Disko will format & mount the target
# disk over /mnt, which completely shadows the USB! Move or bind-mount to /mnt-usb to prevent this.
for shadowed_mount in /mnt/usb /mnt/ventoy /mnt/media; do
    if grep -qs " ${shadowed_mount} " /proc/mounts; then
        echo -e "  ${YELLOW}Notice:${NC} USB is mounted at ${shadowed_mount}. Moving to /mnt-usb to prevent mount shadowing by Disko..."
        mkdir -p /mnt-usb
        mount --bind "$shadowed_mount" /mnt-usb 2>/dev/null || true
        umount -l "$shadowed_mount" 2>/dev/null || true
        if [[ -n "$CACHE_PATH" && "$CACHE_PATH" == "${shadowed_mount}"* ]]; then
            CACHE_PATH="/mnt-usb${CACHE_PATH#"${shadowed_mount}"}"
        fi
        break
    fi
done

if [[ -n "$CACHE_PATH" ]]; then
    # User explicitly specified cache path
    # Handle if user passed directory containing nix-cache/ instead of the cache directory itself
    if [[ ! -f "$CACHE_PATH/nix-cache-info" && -f "$CACHE_PATH/nix-cache/nix-cache-info" ]]; then
        CACHE_PATH="$CACHE_PATH/nix-cache"
    fi

    # Handle /mnt/usb references if moved to /mnt-usb
    if [[ ! -f "$CACHE_PATH/nix-cache-info" && "$CACHE_PATH" == /mnt/usb* ]]; then
        alt_path="/mnt-usb${CACHE_PATH#/mnt/usb}"
        if [[ -f "$alt_path/nix-cache-info" ]]; then
            CACHE_PATH="$alt_path"
        elif [[ -f "$alt_path/nix-cache/nix-cache-info" ]]; then
            CACHE_PATH="$alt_path/nix-cache"
        fi
    fi

    if [[ -f "$CACHE_PATH/nix-cache-info" ]]; then
        CACHE_SUBSTITUTERS="file://$CACHE_PATH"
        echo -e "\n${GREEN}==> ✓ Using pre-built cache:${NC} ${BOLD}$CACHE_PATH${NC}"
    else
        echo -e "\n${RED}Error:${NC} Specified cache path '$CACHE_PATH' is not a valid nix binary cache (missing nix-cache-info)." >&2
        echo -e "${YELLOW}Common causes & quick fixes:${NC}"
        echo -e "  1. Ventoy USB was mounted under /mnt (e.g. /mnt/usb). Disko mounts the target drive to /mnt and shadows it."
        echo -e "     Mount to /mnt-usb instead: mkdir -p /mnt-usb && mount /dev/sdX1 /mnt-usb"
        echo -e "  2. Wrong partition mounted (Ventoy has 2 partitions: mount the large exFAT/NTFS one, NOT VTOYEFI)."
        echo -e "  3. Check mounted drives with: lsblk -f"
        exit 1
    fi
else
    # Auto-detect: look for nix-cache/ on USB/removable media
    echo -e "\n${GREEN}==>$NC Scanning for pre-built binary cache on USB..."
    CACHE_SEARCH_PATHS=()

    # Scan all mounted removable/hotplug devices (strictly excluding /mnt and subpaths)
    while IFS= read -r mp; do
        [[ -n "$mp" && -d "$mp" && "$mp" != "/mnt" && "$mp" != /mnt/* ]] && CACHE_SEARCH_PATHS+=("$mp")
    done < <(lsblk -o MOUNTPOINT,HOTPLUG -nr 2>/dev/null | awk '$2=="1" && $1!="" {print $1}')

    # Check common manual mount points (outside of /mnt)
    for candidate_dir in /mnt-usb /media /usb /tmp/usb; do
        [[ -d "$candidate_dir" ]] && CACHE_SEARCH_PATHS+=("$candidate_dir")
    done
    if [[ -d "/media" ]]; then
        for candidate_dir in /media/*; do
            [[ -d "$candidate_dir" ]] && CACHE_SEARCH_PATHS+=("$candidate_dir")
        done
    fi
    if [[ -d "/run/media" ]]; then
        for candidate_dir in /run/media/*/*; do
            [[ -d "$candidate_dir" ]] && CACHE_SEARCH_PATHS+=("$candidate_dir")
        done
    fi

    # Check parent of where install.sh is running from (if running from USB copy)
    PARENT_OF_SCRIPT="$(dirname "$SCRIPT_DIR")"
    [[ -d "$PARENT_OF_SCRIPT" && "$PARENT_OF_SCRIPT" != "/mnt" && "$PARENT_OF_SCRIPT" != /mnt/* ]] && CACHE_SEARCH_PATHS+=("$PARENT_OF_SCRIPT")

    # Search for nix-cache/ or direct nix-cache-info in candidate paths
    for search_path in "${CACHE_SEARCH_PATHS[@]}"; do
        if [[ -f "$search_path/nix-cache/nix-cache-info" ]]; then
            CACHE_PATH="$search_path/nix-cache"
            CACHE_SUBSTITUTERS="file://$CACHE_PATH"
            echo -e "  ${GREEN}✓ Found pre-built cache:${NC} ${BOLD}$CACHE_PATH${NC}"
            break
        elif [[ -f "$search_path/nix-cache-info" ]]; then
            CACHE_PATH="$search_path"
            CACHE_SUBSTITUTERS="file://$CACHE_PATH"
            echo -e "  ${GREEN}✓ Found pre-built cache:${NC} ${BOLD}$CACHE_PATH${NC}"
            break
        fi
    done

    # If still not found, try auto-discovering unmounted USB partitions (e.g. Ventoy data partition)
    if [[ -z "$CACHE_SUBSTITUTERS" ]]; then
        while IFS= read -r dev; do
            [[ -z "$dev" ]] && continue
            if [[ -n "$TARGET_DISK" && "$dev" =~ ^"$TARGET_DISK" ]]; then
                continue
            fi
            mkdir -p /mnt-usb
            if mount -o ro "$dev" /mnt-usb 2>/dev/null; then
                if [[ -f "/mnt-usb/nix-cache/nix-cache-info" ]]; then
                    CACHE_PATH="/mnt-usb/nix-cache"
                    CACHE_SUBSTITUTERS="file://$CACHE_PATH"
                    echo -e "  ${GREEN}✓ Auto-mounted USB partition ($dev) at /mnt-usb${NC}"
                    echo -e "  ${GREEN}✓ Found pre-built cache:${NC} ${BOLD}$CACHE_PATH${NC}"
                    break
                elif [[ -f "/mnt-usb/nix-cache-info" ]]; then
                    CACHE_PATH="/mnt-usb"
                    CACHE_SUBSTITUTERS="file://$CACHE_PATH"
                    echo -e "  ${GREEN}✓ Auto-mounted USB partition ($dev) at /mnt-usb${NC}"
                    echo -e "  ${GREEN}✓ Found pre-built cache:${NC} ${BOLD}$CACHE_PATH${NC}"
                    break
                else
                    umount /mnt-usb 2>/dev/null || true
                fi
            fi
        done < <(lsblk -lno NAME,TYPE,FSTYPE 2>/dev/null | awk '$2=="part" && ($3=="exfat" || $3=="ntfs" || $3=="vfat" || $3=="ext4") {print "/dev/"$1}')
    fi

    if [[ -z "$CACHE_SUBSTITUTERS" ]]; then
        echo -e "  ${YELLOW}No pre-built cache found on USB.${NC}"
        echo -e "  ${DIM}The system will be built from source / downloaded from cache.nixos.org.${NC}"
        echo -e "  ${DIM}On low-RAM systems (<6GB), consider using pre-build.sh first.${NC}"
    fi
fi

if [[ -n "$CACHE_SUBSTITUTERS" ]]; then
    CACHE_NAR_COUNT=$(find "$CACHE_PATH" -name "*.narinfo" 2>/dev/null | wc -l || echo "0")
    echo -e "  Cache contains ${CYAN}${CACHE_NAR_COUNT}${NC} pre-built store paths"
    echo -e "  ${DIM}Installation will copy from local cache — zero compilation.${NC}"
    CACHE_INSTALL_ARGS=(
        --option substituters "$CACHE_SUBSTITUTERS https://cache.nixos.org/"
        --option trusted-substituters "$CACHE_SUBSTITUTERS https://cache.nixos.org/"
        --option require-sigs false
    )
fi

# Safety Confirmation
echo ""
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "${RED}${BOLD}       ⚠️  CRITICAL DATA LOSS WARNING ⚠️            ${NC}"
echo -e "${RED}${BOLD}====================================================${NC}"
echo -e "You are about to ${RED}${BOLD}COMPLETELY WIPE AND REPARTITION${NC}:"
echo -e "  Disk:         ${YELLOW}${BOLD}$TARGET_DISK${NC} (${DISK_SIZE_GB} GB)"
echo -e "  Host Config:  ${YELLOW}${BOLD}$HOST_NAME${NC}"
echo -e "  Primary User: ${YELLOW}${BOLD}$USER_NAME${NC}"
if [[ -n "$CACHE_SUBSTITUTERS" ]]; then
echo -e "  Binary Cache: ${GREEN}${BOLD}$CACHE_PATH${NC} (${CYAN}${CACHE_NAR_COUNT}${NC} store paths)"
else
echo -e "  Binary Cache: ${YELLOW}None (will build/download from cache.nixos.org)${NC}"
fi
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
nixos-install --flake ".#$HOST_NAME" --no-channel-copy "${CACHE_INSTALL_ARGS[@]}" "${EXTRA_INSTALL_ARGS[@]}"

# 2.5 Post-Install System Configuration
echo -e "\n${GREEN}==>${NC} Setting up user workspace & configuration repository..."

# Copy configuration repository to /home/$USER_NAME/.config/config
mkdir -p "/mnt/home/$USER_NAME/.config/config"
cp -r . "/mnt/home/$USER_NAME/.config/config/"
chown -R 1000:100 "/mnt/home/$USER_NAME/.config"
mkdir -p /mnt/etc
ln -sfn "/home/$USER_NAME/.config/config" /mnt/etc/nixos
echo -e "  ${GREEN}✓ Configuration copied to /home/$USER_NAME/.config/config (linked to /etc/nixos)${NC}"

# Prompt to set password for primary user (sudo access)
echo -e "\n${GREEN}==>${NC} Set login & sudo password for primary user ${BOLD}$USER_NAME${NC}:"
nixos-enter --root /mnt -c "passwd $USER_NAME" || true

# Cleanup temporary installation swap & files
swapoff -a 2>/dev/null || true
[ -f /mnt/swapfile ] && rm -f /mnt/swapfile
rm -rf /mnt/tmp

# 3. Post-install
echo -e "\n${GREEN}${BOLD}[3/3] Installation complete!${NC}"
echo ""
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ NixOS Server Successfully Installed!            ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "Next steps on first boot:"
echo -e "  1. Log in as ${BOLD}$USER_NAME${NC}"
echo -e "  2. Run: ${CYAN}cd ~/.config/config && ./post-install.sh${NC}"
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
