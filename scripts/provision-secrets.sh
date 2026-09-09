#!/usr/bin/env bash
# Run as root. Existing nonempty credentials are never replaced or printed.
set -euo pipefail
umask 077
secrets_dir="${1:-/persist/secrets}"
install -d -m 0700 "$secrets_dir"

create_secret() {
    local name="$1" key="$2" value tmp
    if [[ -e "$secrets_dir/$name" ]]; then
        [[ -s "$secrets_dir/$name" ]] || { echo "Empty secret: $name; restore it instead of generating a new key." >&2; return 1; }
        chmod 0600 "$secrets_dir/$name"
        return
    fi
    value=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
    tmp=$(mktemp "$secrets_dir/.secret.XXXXXX")
    if [[ -n "$key" ]]; then
        printf '%s=%s\n' "$key" "$value" > "$tmp"
    else
        printf '%s\n' "$value" > "$tmp"
    fi
    # Atomic, no replacement if another provisioner already created it.
    ln "$tmp" "$secrets_dir/$name" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
}

create_secret n8n.env N8N_ENCRYPTION_KEY
create_secret nine-router.env INITIAL_PASSWORD
create_secret headroom.env HEADROOM_PROXY_TOKEN
create_secret obsidian-sync-admin-password ''
create_secret restic-password ''
# These credentials must come from the user's accounts, not random generation.
if [[ ! -e "$secrets_dir/photo-gallery.env" ]]; then
    printf '# Add an API key created in Immich, then restart photo-gallery.\nIMMICH_API_KEY=\n' > "$secrets_dir/photo-gallery.env"
fi
if [[ ! -e "$secrets_dir/openhands.env" ]]; then
    printf '# OpenHands is disabled until an isolated execution host is available.\n' > "$secrets_dir/openhands.env"
fi
chmod 0600 "$secrets_dir/photo-gallery.env" "$secrets_dir/openhands.env"
