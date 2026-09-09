#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT
export HOME="$work/home"
mkdir -p "$HOME"

# Provisioning is private, idempotent, and does not print credentials.
bash "$repo/scripts/provision-secrets.sh" "$work/secrets" > "$work/output"
test ! -s "$work/output"
test "$(stat -c %a "$work/secrets")" = 700
for file in n8n.env nine-router.env headroom.env obsidian-sync-admin-password restic-password photo-gallery.env; do
    test -s "$work/secrets/$file"
    test "$(stat -c %a "$work/secrets/$file")" = 600
done
before=$(sha256sum "$work/secrets/n8n.env")
bash "$repo/scripts/provision-secrets.sh" "$work/secrets"
test "$before" = "$(sha256sum "$work/secrets/n8n.env")"
: > "$work/secrets/n8n.env"
if bash "$repo/scripts/provision-secrets.sh" "$work/secrets" 2>/dev/null; then
    echo 'FAIL: silently replaced an empty encryption key' >&2; exit 1
fi
echo 'PASS: secret provisioning preserves keys and restrictive permissions'

# Oversized logs and oversized individual messages stay within the configured bound.
export WANE_LOG_FILE="$work/wane-log" WANE_MAX_SIZE_MB=1
source "$repo/shell-repo/wane-watcher/wane.sh"
trap cleanup EXIT
head -c 2097152 /dev/zero | tr '\0' x > "$LOG_FILE"
printf '\n' >> "$LOG_FILE"
append_log_line 'latest warning'
test "$(stat -c %s "$LOG_FILE")" -le 1048576
test "$(tail -n1 "$LOG_FILE")" = 'latest warning'
large=$(head -c 1500000 /dev/zero | tr '\0' x)
append_log_line "$large"
test "$(stat -c %s "$LOG_FILE")" -le 1048576
echo 'PASS: live log append enforces the size bound'

# Retention never deletes unconfirmed photos; failed uploads are retried.
export STORAGE_DIR="$work/captures" STATE_FILE="$work/capture-state" KEEP_LOCAL_DAYS=1
mkdir -p "$STORAGE_DIR"
source "$repo/shell-repo/photo-gallery/photo-gallery.sh"
touch "$STORAGE_DIR/uploaded.jpg" "$STORAGE_DIR/pending.jpg"
touch -d '5 days ago' "$STORAGE_DIR/uploaded.jpg" "$STORAGE_DIR/pending.jpg"
touch "$STORAGE_DIR/uploaded.jpg.uploaded"
cleanup_local_storage
test ! -e "$STORAGE_DIR/uploaded.jpg"
test -e "$STORAGE_DIR/pending.jpg"
immich_upload_and_index() { return 1; }
if retry_pending_uploads; then echo 'FAIL: failed upload reported success' >&2; exit 1; fi
test -e "$STORAGE_DIR/pending.jpg"
test ! -e "$STORAGE_DIR/pending.jpg.uploaded"
immich_upload_and_index() { printf '%s\n' "$1" >> "$work/upload-attempts"; }
retry_pending_uploads
test -s "$work/upload-attempts"
test ! -e "$STORAGE_DIR/pending.jpg"
echo 'PASS: only confirmed uploads expire; failed uploads remain queued'

# A failed upload still records the capture day to prevent a tight capture loop.
check_dependencies() { return 0; }
check_env() { return 0; }
capture_photo() { touch "$1"; }
immich_upload_and_index() { return 1; }
if with_storage_lock run_capture_and_upload; then echo 'FAIL: expected failed upload' >&2; exit 1; fi
test "$(cat "$STATE_FILE")" = "$(date +%Y-%m-%d)"
test -n "$(find "$STORAGE_DIR" -name '*.jpg' -print -quit)"
echo 'PASS: capture scheduling remains stable during an upload outage'

for script in "$repo"/*.sh "$repo"/scripts/*.sh "$repo"/shell-repo/*/*.sh; do
    bash -n "$script"
done
echo 'PASS: all shell scripts parse'
