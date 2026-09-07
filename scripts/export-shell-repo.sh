#!/usr/bin/env bash
# ==============================================================================
# Shell-Repo Private Repository Exporter & Submodule Migration Helper
# ==============================================================================
# This script automates extracting `shell-repo/` into a standalone, private
# Git repository on GitHub (or GitLab/Gitea), and optionally converts it into
# a Git submodule inside your Flint NixOS repository.
#
# Usage:
#   ./scripts/export-shell-repo.sh [OPTIONS]
#
# Options:
#   --repo-url <url>      Destination private Git remote URL
#                         (e.g., git@github.com:username/homelab-shell-repo.git)
#   --mode <mode>         Migration mode: 'submodule', 'standalone', or 'export-only'
#                         Default: interactive prompt
#   --branch <name>       Target branch name (default: main)
#   --dry-run             Preview actions without executing git push or submodule edits
#   -h, --help            Show this help message
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
REPO_URL=""
MODE=""
BRANCH="main"
DRY_RUN=false

# Root verification
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

show_help() {
    echo -e "${BOLD}Usage:${NC} ./scripts/export-shell-repo.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Description:${NC}"
    echo -e "  Extracts the 'shell-repo/' directory into a standalone Git repository"
    echo -e "  ready to be hosted in a private repository, protecting private automation"
    echo -e "  daemons, camera configs, and personal scripts."
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  --repo-url <url>      Destination private Git remote URL"
    echo -e "                        (e.g. git@github.com:davindakhrisna/homelab-shell-repo.git)"
    echo -e "  --mode <mode>         Migration mode:"
    echo -e "                          • 'submodule'   : Push to remote & convert local shell-repo to git submodule"
    echo -e "                          • 'standalone'  : Push to remote for clone into /persist/shell-repo"
    echo -e "                          • 'export-only' : Initialize local git repo in /tmp without remote push"
    echo -e "  --branch <name>       Target branch (default: main)"
    echo -e "  --dry-run             Simulate without modifying repositories or pushing"
    echo -e "  -h, --help            Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  # Interactive mode"
    echo -e "  ./scripts/export-shell-repo.sh"
    echo ""
    echo -e "  # Non-interactive submodule migration"
    echo -e "  ./scripts/export-shell-repo.sh --repo-url git@github.com:davindakhrisna/homelab-shell-repo.git --mode submodule"
}

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${BLUE}${BOLD}  🔒 Shell-Repo Private Repository Exporter        ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Verify we are in the correct repository root
if [[ ! -f "${ROOT_DIR}/flake.nix" ]] || [[ ! -d "${ROOT_DIR}/shell-repo" ]]; then
    echo -e "${RED}${BOLD}Error:${NC} Must be executed from or within the Flint NixOS flake repository."
    echo -e "Expected to find: ${ROOT_DIR}/flake.nix and ${ROOT_DIR}/shell-repo"
    exit 1
fi

SHELL_REPO_DIR="${ROOT_DIR}/shell-repo"
TEMP_EXPORT_DIR="/tmp/shell-repo-export-$(date +%s)"

echo -e "${GREEN}✓ Verified Flint repository at:${NC} ${ROOT_DIR}"
echo -e "${GREEN}✓ Source shell-repo located at:${NC} ${SHELL_REPO_DIR}"
echo ""

# Interactive Mode Selection if not passed
if [[ -z "$MODE" ]]; then
    echo -e "${BOLD}Select migration mode:${NC}"
    echo -e "  ${CYAN}1)${NC} ${BOLD}Git Submodule (Recommended)${NC}"
    echo -e "     Push shell-repo to private GitHub repo and link it as a Git submodule in server-nixos."
    echo -e "  ${CYAN}2)${NC} ${BOLD}Standalone Private Repo${NC}"
    echo -e "     Push shell-repo to private GitHub repo for independent cloning (e.g. into /persist/shell-repo)."
    echo -e "  ${CYAN}3)${NC} ${BOLD}Local Export Only${NC}"
    echo -e "     Initialize git repo in ${TEMP_EXPORT_DIR} without pushing to GitHub."
    echo ""
    read -rp "Enter choice [1-3] (default 1): " MODE_CHOICE
    case "${MODE_CHOICE:-1}" in
        1) MODE="submodule" ;;
        2) MODE="standalone" ;;
        3) MODE="export-only" ;;
        *) echo -e "${RED}Invalid choice. Aborting.${NC}"; exit 1 ;;
    esac
fi

# Request Repo URL if needed
if [[ "$MODE" != "export-only" ]] && [[ -z "$REPO_URL" ]]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Enter your private GitHub repository URL:${NC}"
    echo -e "Example: ${CYAN}git@github.com:davindakhrisna/homelab-shell-repo.git${NC}"
    read -rp "Repo URL: " REPO_URL
    if [[ -z "$REPO_URL" ]]; then
        echo -e "${RED}Error: Repository URL is required for '${MODE}' mode.${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${CYAN}${BOLD}[1/4] Preparing Clean Export Directory...${NC}"
mkdir -p "$TEMP_EXPORT_DIR"
cp -r "${SHELL_REPO_DIR}/." "$TEMP_EXPORT_DIR/"

# Remove any accidental git metadata or log files in export
rm -rf "${TEMP_EXPORT_DIR}/.git" "${TEMP_EXPORT_DIR}/*wane-log*" "${TEMP_EXPORT_DIR}/.DS_Store"

# Create master README in exported repo if not present
if [[ ! -f "${TEMP_EXPORT_DIR}/README.md" ]]; then
    cat <<'EOF' > "${TEMP_EXPORT_DIR}/README.md"
# 🔒 Homelab Shell-Repo: Private Automation Daemons

This repository contains private background daemons, system automation scripts, and custom service units for the Flint Homelab Server.

## 📂 Daemons Included

- **auto-vc:** 24/7 automated git add, commit, and push daemon using dedicated SSH deploy keys.
- **photo-gallery:** Life Museum 24/7 automated camera capture and Immich sync daemon.
- **wane-watcher:** 24/7 system error and warning journal watcher and CLI log inspector.

## 🚀 Usage

Each daemon can be run standalone or invoked via systemd managed by Flint NixOS.
EOF
fi

echo -e "${GREEN}✓ Copied all daemons to temporary workspace:${NC} ${TEMP_EXPORT_DIR}"

echo ""
echo -e "${CYAN}${BOLD}[2/4] Initializing Standalone Git Repository...${NC}"
cd "$TEMP_EXPORT_DIR"
git init -b "$BRANCH"
git config user.name "Flint Automation"
git config user.email "flint@homelab.local"
git add -A
git commit -m "feat: initial export of homelab shell-repo daemons

Includes:
- auto-vc (24/7 automated git sync daemon)
- photo-gallery (Life Museum camera capture & Immich sync)
- wane-watcher (system warning & error watcher daemon & CLI)
"

echo -e "${GREEN}✓ Clean initial commit created on branch '${BRANCH}'.${NC}"

# Push if remote is specified
if [[ "$MODE" != "export-only" ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}[3/4] Pushing to Private Remote (${REPO_URL})...${NC}"
    git remote add origin "$REPO_URL"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would execute: git push -u origin ${BRANCH}${NC}"
    else
        echo -e "Executing: ${BOLD}git push -u origin ${BRANCH}${NC}"
        if git push -u origin "$BRANCH"; then
            echo -e "${GREEN}✓ Successfully pushed shell-repo to private remote!${NC}"
        else
            echo -e "${RED}${BOLD}Push failed!${NC}"
            echo -e "Ensure that the remote repository exists on GitHub and that your SSH key has write access."
            echo -e "Local export is preserved at: ${TEMP_EXPORT_DIR}"
            exit 1
        fi
    fi
else
    echo ""
    echo -e "${CYAN}${BOLD}[3/4] Skipped remote push (export-only mode).${NC}"
fi

# Submodule conversion if requested
echo ""
echo -e "${CYAN}${BOLD}[4/4] Finalizing Flint Repository Setup...${NC}"
cd "$ROOT_DIR"

if [[ "$MODE" == "submodule" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] Would remove ${SHELL_REPO_DIR} and add submodule pointing to ${REPO_URL}${NC}"
    else
        echo -e "Converting ${BOLD}shell-repo/${NC} into a Git submodule..."
        
        # Backup original directory just in case
        BACKUP_DIR="${ROOT_DIR}/shell-repo.bak.$(date +%s)"
        cp -r "$SHELL_REPO_DIR" "$BACKUP_DIR"
        echo -e "${YELLOW}Original files backed up to:${NC} ${BACKUP_DIR}"

        # Remove from git index
        git rm -r --cached shell-repo 2>/dev/null || true
        rm -rf shell-repo

        # Add submodule
        git submodule add "$REPO_URL" shell-repo
        git submodule update --init --recursive

        echo -e "${GREEN}✓ Git submodule added successfully!${NC}"
        echo -e "Run ${BOLD}git commit -m 'refactor: convert shell-repo to private git submodule'${NC} to commit changes."
        echo -e "You may now remove the backup directory: ${BACKUP_DIR}"
    fi
elif [[ "$MODE" == "standalone" ]]; then
    echo -e "${GREEN}✓ Standalone private repository ready.${NC}"
    echo -e "To use as standalone on your homelab:"
    echo -e "  1. Clone into persistent storage: ${CYAN}git clone ${REPO_URL} /persist/shell-repo${NC}"
    echo -e "  2. Point custom services to /persist/shell-repo in hosts/homelab/default.nix"
fi

# Clean up temporary dir
rm -rf "$TEMP_EXPORT_DIR"

echo ""
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}  ✓ Shell-Repo Migration Complete!                  ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "Destination Remote: ${BOLD}${REPO_URL:-Local Only}${NC}"
echo -e "Migration Mode:     ${BOLD}${MODE}${NC}"
echo ""
echo -e "${YELLOW}${BOLD}Important Nix Flake Submodule Note:${NC}"
echo -e "When using Git submodules in a Nix Flake, remember to pass ${CYAN}--submodules${NC}"
echo -e "or ensure your git configuration has ${CYAN}submodule.recurse = true${NC}:"
echo -e "  ${BOLD}git config submodule.recurse true${NC}"
echo -e "  ${BOLD}nix build --submodules .#nixosConfigurations.homelab.config.system.build.toplevel${NC}"
echo ""
