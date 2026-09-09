#!/usr/bin/env bash
# The NixOS module supplies SNAPSHOT_DIR and newline-separated BACKUP_UNITS.
set -euo pipefail
umask 077
: "${SNAPSHOT_DIR:?}" "${BACKUP_UNITS:?}"
[[ "$SNAPSHOT_DIR" == /var/lib/homelab-backup/snapshots ]] || exit 1
active_file=/var/lib/homelab-backup/active-units

resume_services() {
    if [[ -s "$active_file" ]]; then
        mapfile -t active < "$active_file"
        systemctl start --no-block "${active[@]}" || return 1
    fi
    rm -f "$active_file"
}

remove_snapshots() {
    local name
    for name in root persist home; do
        if [[ -e "$SNAPSHOT_DIR/$name" ]]; then
            # Delete only these named Btrfs subvolumes, never recursive file trees.
            btrfs subvolume delete "$SNAPSHOT_DIR/$name"
        fi
    done
}

case "${1:-}" in
    prepare)
        install -d -m 0700 "$SNAPSHOT_DIR"
        resume_services
        remove_snapshots
        : > "$active_file"
        while IFS= read -r unit; do
            if systemctl is-active --quiet "$unit"; then
                printf '%s\n' "$unit" >> "$active_file"
            fi
        done <<< "$BACKUP_UNITS"
        # Resume services even if stop or snapshot creation fails midway.
        trap resume_services EXIT
        if [[ -s "$active_file" ]]; then
            mapfile -t active < "$active_file"
            systemctl stop "${active[@]}"
        fi
        btrfs subvolume snapshot -r / "$SNAPSHOT_DIR/root"
        btrfs subvolume snapshot -r /persist "$SNAPSHOT_DIR/persist"
        btrfs subvolume snapshot -r /home "$SNAPSHOT_DIR/home"
        ;;
    cleanup)
        resume_services
        remove_snapshots
        ;;
    *) echo 'Expected prepare or cleanup' >&2; exit 1 ;;
esac
