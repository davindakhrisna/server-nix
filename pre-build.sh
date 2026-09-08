#!/usr/bin/env bash
# ==============================================================================
# NixOS Server Pre-Build & USB Cache Exporter
# ==============================================================================
# Run this on your POWERFUL machine to pre-build the entire NixOS system
# closure and export it as a local Nix binary cache onto your Ventoy USB.
#
# The homelab server (4GB RAM) can then install from this cache with zero
# compilation overhead — just copying pre-built store paths.
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

HOST_NAME="homelab"
USB_PATH=""
SKIP_CONFIRM=false
SKIP_REPO_COPY=false

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]

${BOLD}Pre-build the NixOS system closure and export to a Ventoy USB.${NC}

${BOLD}Options:${NC}
  -u, --usb <path>        Path to Ventoy USB mount (e.g., /run/media/$USER/Ventoy)
  -H, --host <hostname>   NixOS host configuration to build (default: homelab)
  -y, --yes               Skip confirmation prompts
  --no-repo-copy          Skip copying the flake repository to the USB
  -h, --help              Show this help message

${BOLD}Examples:${NC}
  # Interactive: prompts for USB path
  $0

  # Direct path to Ventoy USB
  $0 --usb /run/media/$USER/Ventoy

  # Build a specific host config
  $0 --host homelab --usb /run/media/$USER/Ventoy"
    exit 0
}

# Parse CLI Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--usb)
            USB_PATH="$2"
            shift 2
            ;;
        -H|--host)
            HOST_NAME="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        --no-repo-copy)
            SKIP_REPO_COPY=true
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
echo -e "${BLUE}${BOLD}   📦 NixOS Pre-Build & USB Cache Exporter          ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Verify Host Directory Exists
if [[ ! -d "hosts/$HOST_NAME" ]]; then
    echo -e "${RED}Error:${NC} Host configuration 'hosts/$HOST_NAME' not found!" >&2
    echo "Available hosts:"
    ls -1 hosts | sed 's/^/  - /'
    exit 1
fi

# Verify nix is available with flakes
if ! command -v nix &>/dev/null; then
    echo -e "${RED}Error:${NC} 'nix' command not found. Install Nix first: https://nixos.org/download" >&2
    exit 1
fi

# ==============================================================================
# 1. Locate Ventoy USB
# ==============================================================================
echo -e "${CYAN}${BOLD}[1/4] Locating Ventoy USB drive...${NC}"

if [[ -z "$USB_PATH" ]]; then
    # Auto-detect: scan common mount points for Ventoy partitions
    VENTOY_CANDIDATES=()

    # Check /run/media/$USER/ (most desktop Linux auto-mount location)
    if [[ -d "/run/media/$USER" ]]; then
        for mount_dir in /run/media/"$USER"/*/; do
            [[ -d "$mount_dir" ]] && VENTOY_CANDIDATES+=("${mount_dir%/}")
        done
    fi

    # Check /media/$USER/ (Ubuntu/Debian auto-mount)
    if [[ -d "/media/$USER" ]]; then
        for mount_dir in /media/"$USER"/*/; do
            [[ -d "$mount_dir" ]] && VENTOY_CANDIDATES+=("${mount_dir%/}")
        done
    fi

    # Check /mnt/ for manual mounts
    for mount_dir in /mnt/*/; do
        [[ -d "$mount_dir" ]] && VENTOY_CANDIDATES+=("${mount_dir%/}")
    done

    # Also check lsblk for any removable or USB disks mounted elsewhere
    while IFS= read -r mp; do
        [[ -n "$mp" && -d "$mp" ]] && VENTOY_CANDIDATES+=("$mp")
    done < <(lsblk -o MOUNTPOINT,HOTPLUG -nr 2>/dev/null | awk '$2=="1" && $1!="" {print $1}')

    # Deduplicate
    mapfile -t VENTOY_CANDIDATES < <(printf '%s\n' "${VENTOY_CANDIDATES[@]}" | sort -u)

    if [[ ${#VENTOY_CANDIDATES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No USB drives auto-detected.${NC}"
        echo ""
        read -rp "Enter the mount path of your Ventoy USB: " USB_PATH
    elif [[ ${#VENTOY_CANDIDATES[@]} -eq 1 ]]; then
        USB_PATH="${VENTOY_CANDIDATES[0]}"
        echo -e "  ${GREEN}==>$NC Auto-detected USB: ${BOLD}$USB_PATH${NC}"
    else
        echo -e "${YELLOW}Multiple USB mount points detected:${NC}"
        for i in "${!VENTOY_CANDIDATES[@]}"; do
            local_size=$(df -h "${VENTOY_CANDIDATES[$i]}" 2>/dev/null | awk 'NR==2 {print $2}' || echo "?")
            echo -e "  ${BOLD}$((i+1)))${NC} ${VENTOY_CANDIDATES[$i]} ${DIM}(${local_size})${NC}"
        done
        echo ""
        read -rp "Select USB drive [1-${#VENTOY_CANDIDATES[@]}]: " USB_CHOICE
        USB_PATH="${VENTOY_CANDIDATES[$((USB_CHOICE-1))]}"
    fi
fi

# Validate USB path
if [[ ! -d "$USB_PATH" ]]; then
    echo -e "${RED}Error:${NC} USB path '$USB_PATH' does not exist or is not mounted!" >&2
    exit 1
fi

# Check available space (need at least 5GB for a typical NixOS closure cache)
USB_AVAIL_KB=$(df -k "$USB_PATH" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
USB_AVAIL_GB=$(( USB_AVAIL_KB / 1024 / 1024 ))
if [[ "$USB_AVAIL_GB" -lt 5 ]]; then
    echo -e "${YELLOW}⚠️  Warning: Only ${USB_AVAIL_GB}GB available on $USB_PATH. A full system cache typically needs 5-10GB.${NC}"
    if [[ "$SKIP_CONFIRM" != true ]]; then
        read -rp "Continue anyway? [y/N]: " SPACE_CONFIRM
        [[ ! "$SPACE_CONFIRM" =~ ^[Yy]$ ]] && exit 1
    fi
fi

CACHE_DIR="$USB_PATH/nix-cache"
REPO_DIR="$USB_PATH/server-nixos"

echo -e "  USB Path:   ${BOLD}$USB_PATH${NC}"
echo -e "  Cache Dir:  ${BOLD}$CACHE_DIR${NC}"
echo -e "  Available:  ${CYAN}${USB_AVAIL_GB}GB${NC}"
echo ""

# ==============================================================================
# 2. Build System Closure
# ==============================================================================
echo -e "${CYAN}${BOLD}[2/4] Building NixOS system closure for '${HOST_NAME}'...${NC}"
echo -e "  ${DIM}This may take a while on first run (downloading + compiling).${NC}"
echo -e "  ${DIM}Subsequent runs with no config changes will be near-instant.${NC}"
echo ""

BUILD_TARGET=".#nixosConfigurations.${HOST_NAME}.config.system.build.toplevel"

nix build "$BUILD_TARGET" --show-trace 2>&1 | while IFS= read -r line; do
    echo -e "  ${DIM}${line}${NC}"
done

if [[ ! -L "./result" ]]; then
    echo -e "${RED}Error:${NC} Build failed — no ./result symlink found." >&2
    exit 1
fi

CLOSURE_PATH=$(readlink -f ./result)
echo ""
echo -e "  ${GREEN}✓ Build successful!${NC}"
echo -e "  Closure: ${BOLD}$CLOSURE_PATH${NC}"

# Count store paths in the closure
CLOSURE_SIZE=$(nix path-info -S "$BUILD_TARGET" 2>/dev/null | awk '{print $2}' || echo "unknown")
CLOSURE_PATHS=$(nix path-info -r "$BUILD_TARGET" 2>/dev/null | wc -l || echo "unknown")
echo -e "  Closure size: ${CYAN}${CLOSURE_SIZE}${NC} across ${CYAN}${CLOSURE_PATHS}${NC} store paths"
echo ""

# ==============================================================================
# 3. Export Binary Cache to USB
# ==============================================================================
echo -e "${CYAN}${BOLD}[3/4] Exporting binary cache to USB...${NC}"
echo -e "  ${DIM}Copying ${CLOSURE_PATHS} store paths to ${CACHE_DIR}${NC}"
echo -e "  ${DIM}This creates a flat file cache (.narinfo + .nar.xz) — no symlinks needed.${NC}"
echo ""

mkdir -p "$CACHE_DIR"

nix copy --to "file://$CACHE_DIR" "$BUILD_TARGET" 2>&1 | while IFS= read -r line; do
    echo -e "  ${DIM}${line}${NC}"
done

# Verify cache was created
if [[ ! -f "$CACHE_DIR/nix-cache-info" ]]; then
    echo -e "${RED}Error:${NC} Cache export failed — nix-cache-info not found in $CACHE_DIR" >&2
    exit 1
fi

CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
CACHE_NAR_COUNT=$(find "$CACHE_DIR" -name "*.narinfo" 2>/dev/null | wc -l || echo "unknown")

echo -e "  ${GREEN}✓ Binary cache exported successfully!${NC}"
echo -e "  Cache size on USB: ${CYAN}${CACHE_SIZE}${NC}"
echo -e "  Cached paths:      ${CYAN}${CACHE_NAR_COUNT}${NC} .narinfo entries"
echo ""

# ==============================================================================
# 4. Copy Flake Repository to USB
# ==============================================================================
if [[ "$SKIP_REPO_COPY" != true ]]; then
    echo -e "${CYAN}${BOLD}[4/4] Copying flake repository to USB...${NC}"

    # Use rsync if available for incremental copy, otherwise cp
    if command -v rsync &>/dev/null; then
        rsync -a --delete \
            --exclude '.git' \
            --exclude 'result' \
            --exclude 'nix-cache' \
            ./ "$REPO_DIR/"
    else
        rm -rf "$REPO_DIR"
        mkdir -p "$REPO_DIR"
        # Copy everything except .git, result symlink, and nix-cache
        find . -maxdepth 1 ! -name '.' ! -name '.git' ! -name 'result' ! -name 'nix-cache' \
            -exec cp -r {} "$REPO_DIR/" \;
    fi

    # Initialize a minimal git repo so the flake can be evaluated
    # (Nix flakes require the directory to be a git repo or have flake.nix tracked)
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        (cd "$REPO_DIR" && git init -q && git add -A && git commit -q -m "pre-build snapshot" --allow-empty)
    fi

    echo -e "  ${GREEN}✓ Repository copied to ${BOLD}${REPO_DIR}${NC}"
else
    echo -e "${CYAN}${BOLD}[4/4] Skipping repository copy (--no-repo-copy)${NC}"
fi

# Ensure dirty memory buffers are fully flushed to physical USB
echo -e "\n  ${CYAN}==>${NC} Flushing write cache to USB (sync)..."
sync
echo -e "  ${GREEN}✓ Write cache flushed.${NC} Safe to unmount/unplug."

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ Pre-Build Complete!                            ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "  Host Config:   ${BOLD}${HOST_NAME}${NC}"
echo -e "  Binary Cache:  ${BOLD}${CACHE_DIR}${NC} (${CACHE_SIZE})"
if [[ "$SKIP_REPO_COPY" != true ]]; then
echo -e "  Flake Repo:    ${BOLD}${REPO_DIR}${NC}"
fi
echo ""
echo -e "${BOLD}Next steps on homelab (4GB RAM):${NC}"
echo -e "  1. Boot your homelab from the Ventoy USB (NixOS minimal ISO)"
echo -e "  2. Mount the Ventoy data partition (use /mnt-usb, NOT /mnt/usb):"
echo -e "     ${CYAN}# Note: Disko mounts the target OS to /mnt, so we use /mnt-usb to avoid mount shadowing!${NC}"
echo -e "     ${BOLD}lsblk -f${NC}   ${DIM}# Identify Ventoy partition (usually the large exFAT/NTFS one)${NC}"
echo -e "     ${BOLD}mkdir -p /mnt-usb && mount /dev/sdX1 /mnt-usb${NC}"
echo -e "  3. Run the installer from the USB copy:"
echo -e "     ${BOLD}cd /mnt-usb/server-nixos${NC}"
echo -e "     ${BOLD}sudo ./install.sh${NC}   ${DIM}(auto-detects cache at /mnt-usb/nix-cache)${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
