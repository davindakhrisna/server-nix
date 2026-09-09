#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/shell-regressions.sh
bash tests/backup-regressions.sh
nix flake check --no-build path:.
nix eval --impure --json path:.#nixosConfigurations.homelab.config \
    --apply 'import ./tests/config-check.nix'
