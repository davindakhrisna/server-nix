#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/shell-regressions.sh
bash tests/backup-regressions.sh
# The Git-filtered source excludes ignored deployment inventory. It must remain
# safe to inspect and must not expose a buildable real-host configuration.
nix flake check --no-build .
if nix eval --raw .#nixosConfigurations.homelab.config.networking.hostName >/dev/null 2>&1; then
    echo "FAIL: Git-filtered flake unexpectedly exposes homelab without _local.nix" >&2
    exit 1
fi
nix flake check --no-build path:.
nix eval --impure --json path:.#nixosConfigurations.homelab.config \
    --apply 'import ./tests/config-check.nix'
nix eval --impure --json path:.#nixosConfigurations.template.config \
    --apply 'import ./tests/template-config-check.nix'
