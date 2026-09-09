#!/usr/bin/env bash
# Exercise failure recovery with fake systemctl/btrfs; never stop real services.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/state"
# Redirect the production helper's fixed state paths into the test sandbox.
sed "s|/var/lib/homelab-backup|$work/state|g" "$repo/scripts/backup-snapshot.sh" > "$work/helper.sh"
export SNAPSHOT_DIR="$work/state/snapshots" MOCK_LOG="$work/events"
export BACKUP_UNITS=$'app.service\npostgresql.service\ninactive.service'
cat > "$work/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$MOCK_LOG"
case "$1" in
    is-active) [[ "$3" != inactive.service ]] ;;
    stop) [[ "${FAIL_STOP:-false}" != true ]] ;;
    start) exit 0 ;;
    *) exit 1 ;;
esac
MOCK
cat > "$work/bin/btrfs" <<'MOCK'
#!/usr/bin/env bash
printf 'btrfs %s\n' "$*" >> "$MOCK_LOG"
case "$2" in
    snapshot)
        [[ "${FAIL_SOURCE:-}" != "$4" ]] || exit 1
        mkdir "$5"
        ;;
    delete) rmdir "$3" ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

export FAIL_SOURCE=/persist
if bash "$work/helper.sh" prepare; then echo 'FAIL: snapshot failure was ignored' >&2; exit 1; fi
grep -q '^systemctl start --no-block app.service postgresql.service$' "$MOCK_LOG"
test ! -e "$work/state/active-units"
bash "$work/helper.sh" cleanup
test ! -e "$SNAPSHOT_DIR/root"
echo 'PASS: snapshot failure resumes active services and cleanup removes partial snapshots'

: > "$MOCK_LOG"
unset FAIL_SOURCE
export FAIL_STOP=true
if bash "$work/helper.sh" prepare; then echo 'FAIL: stop failure was ignored' >&2; exit 1; fi
grep -q '^systemctl start --no-block app.service postgresql.service$' "$MOCK_LOG"
test ! -e "$SNAPSHOT_DIR/root"
echo 'PASS: a partial service-stop failure still resumes services'

: > "$MOCK_LOG"
unset FAIL_STOP
bash "$work/helper.sh" prepare
for name in root persist home; do test -d "$SNAPSHOT_DIR/$name"; done
grep -q '^systemctl start --no-block app.service postgresql.service$' "$MOCK_LOG"
if grep -q '^systemctl start .*inactive.service' "$MOCK_LOG"; then exit 1; fi
bash "$work/helper.sh" cleanup
for name in root persist home; do test ! -e "$SNAPSHOT_DIR/$name"; done
echo 'PASS: successful preparation resumes only previously active services'
