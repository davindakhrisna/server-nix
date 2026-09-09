#!/usr/bin/env bash
# ==============================================================================
# NixOS Server Post-Installation & GitHub 24/7 Deploy Key Setup Helper
# ==============================================================================
# Run this script after booting into your new NixOS homelab server to:
#  1. Generate and register a dedicated 24/7 GitHub Deploy Key (Write Access)
#  2. Test GitHub SSH authentication
#  3. Switch git remote to SSH (git@github.com:...)
#  4. Verify / activate Tailscale with Tailscale SSH
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

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_github_deploy"
REPO_DEFAULT="davindakhrisna/server-nixos"

echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${BLUE}${BOLD}   ❄️  NixOS Server: Post-Installation Setup Helper  ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# 1. GitHub 24/7 Deploy Key Setup
# ------------------------------------------------------------------------------
echo -e "${CYAN}${BOLD}[1/3] Setting up GitHub Deploy Key (24/7 Unattended Push)...${NC}"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$KEY_FILE" ]]; then
    echo -e "${YELLOW}Existing deploy key found at:${NC} $KEY_FILE"
else
    echo -e "${GREEN}==>${NC} Generating new dedicated Ed25519 deploy key..."
    ssh-keygen -t ed25519 -C "homelab-deploy-24/7" -f "$KEY_FILE" -N ""
    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"
    echo -e "${GREEN}✓ Key pair generated successfully.${NC}"
fi

PUB_KEY=$(cat "${KEY_FILE}.pub")

echo ""
echo -e "${YELLOW}${BOLD}================================================================${NC}"
echo -e "${BOLD}📋 COPY THIS PUBLIC KEY TO GITHUB:${NC}"
echo -e "${YELLOW}${BOLD}================================================================${NC}"
echo -e "${GREEN}${PUB_KEY}${NC}"
echo -e "${YELLOW}${BOLD}================================================================${NC}"
echo ""
echo -e "${BOLD}Steps to add to GitHub:${NC}"
echo -e "  1. Open: ${CYAN}https://github.com/${REPO_DEFAULT}/settings/keys/new${NC}"
echo -e "  2. Title: ${BOLD}Homelab Server (24/7 Deploy)${NC}"
echo -e "  3. Key: Paste the green line above"
echo -e "  4. ${RED}${BOLD}CRITICAL:${NC} Check the box ${BOLD}'Allow write access'${NC} (allows 24/7 git pushes)"
echo ""
read -rp "Press [Enter] once you have added the key to GitHub to test the connection... "

# ------------------------------------------------------------------------------
# 2. Test GitHub Authentication
# ------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}[2/3] Verifying GitHub SSH Authentication...${NC}"

TEST_OUTPUT=$(ssh -T -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 || true)

if echo "$TEST_OUTPUT" | grep -qi "successfully authenticated"; then
    echo -e "${GREEN}${BOLD}✓ Authentication successful!${NC}"
    echo -e "  $TEST_OUTPUT"
else
    echo -e "${RED}${BOLD}⚠️  Authentication failed or key not yet recognized:${NC}"
    echo -e "  $TEST_OUTPUT"
    echo -e "${YELLOW}Double check that the key was saved with write access in GitHub Settings -> Deploy Keys.${NC}"
fi

# Convert repository remote to SSH if currently HTTPS
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || true)
    if [[ "$CURRENT_REMOTE" =~ ^https://github.com/ ]]; then
        SSH_REMOTE="git@github.com:${REPO_DEFAULT}.git"
        echo ""
        echo -e "${YELLOW}Current git remote is HTTPS:${NC} $CURRENT_REMOTE"
        read -rp "Would you like to switch remote to SSH ($SSH_REMOTE)? [Y/n]: " SWITCH_REMOTE
        if [[ ! "$SWITCH_REMOTE" =~ ^[Nn]$ ]]; then
            git remote set-url origin "$SSH_REMOTE"
            echo -e "${GREEN}✓ Remote updated to:${NC} $SSH_REMOTE"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 3. Tailscale Status & Tailscale SSH
# ------------------------------------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}[3/3] Checking Tailscale Connectivity...${NC}"

if command -v tailscale >/dev/null 2>&1; then
    if tailscale status >/dev/null 2>&1; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Unknown")
        echo -e "${GREEN}✓ Tailscale is connected!${NC}"
        echo -e "  Tailscale IPv4: ${BOLD}$TAILSCALE_IP${NC}"
    else
        echo -e "${YELLOW}Tailscale is installed but not currently logged in.${NC}"
        read -rp "Would you like to log in to Tailscale now with Tailscale SSH enabled? [Y/n]: " RUN_TAILSCALE
        if [[ ! "$RUN_TAILSCALE" =~ ^[Nn]$ ]]; then
            echo -e "${GREEN}==>${NC} Running 'sudo tailscale up --ssh'..."
            sudo tailscale up --ssh
        fi
    fi
else
    echo -e "${YELLOW}Tailscale CLI not found in current PATH.${NC}"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo 'Setting up service credentials and authenticated NAS access...'
sudo systemctl start homelab-secrets.service
if systemctl is-active --quiet samba-smbd.service; then
    echo "Set the Samba password for $USER (used to connect to the NAS):"
    sudo smbpasswd -a "$USER"
fi
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
    sudo systemctl restart tailscale-serve.service
    tailscale serve status
fi
echo 'Add your Immich API key to /persist/secrets/photo-gallery.env, then restart photo-gallery.'
echo 'Keep a separate copy of /persist/secrets/restic-password; the backup cannot be recovered without it.'
echo 'See docs/operations.md for migration, backups and restore verification.'

echo ""
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ Post-Installation Setup Complete!              ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "Your homelab server is now configured to:"
echo -e "  • Push changes to ${BOLD}${REPO_DEFAULT}${NC} 24/7 without password prompts."
echo -e "  • Authenticate via dedicated deploy key: ${CYAN}${KEY_FILE}${NC}"
echo -e "  • Accept secure SSH connections over Tailscale."
echo ""
echo -e "To rebuild your system anytime, run:"
echo -e "  ${BOLD}nh os switch${NC}"
echo ""
