# Operating and upgrading the homelab

## Apply the hardening update

Build before switching: `nix build .#nixosConfigurations.homelab.config.system.build.toplevel`.
Keep an SSH session open, then use `nh os switch`. This repository update does not
itself change a running server. New files must be tracked in Git before a normal
Git-backed flake build; `nix build path:.#nixosConfigurations.homelab.config.system.build.toplevel`
can validate the whole working directory before committing.

Web backends now bind to loopback. Their old LAN HTTP addresses stop working.
OpenHands is disabled, and the dashboard no longer has Docker engine access.
Auto-VC and its repository/log destination are unchanged.

## Tailscale SSH and HTTPS access

SSH is intentionally not open on the LAN or public interfaces. Apply
[`tailscale-policy.homelab.hujson`](tailscale-policy.homelab.hujson) in the
Tailscale admin console (or adapt
[`tailscale-policy.example.hujson`](tailscale-policy.example.hujson) for another
tailnet), then connect from another device signed in to the permitted Tailscale
identity with `ssh kryisnn@homelab`. The ready-to-apply policy uses
`autogroup:self` because this server is a user-owned node; do not tag it unless
you also adapt the policy for a tagged server. Tailscale SSH verifies the
tailnet identity; it does not use your normal SSH public key. A policy denial means the tailnet
policy needs adjustment, while an ordinary OpenSSH `publickey` error concerns
the target account's authorized keys.

The homelab policy uses `action: "accept"` so mobile SSH clients do not have to
complete an interactive browser check. In Termius, use `homelab` (or the
100.x Tailscale address) on port 22 with username `kryisnn` and no password or
private key. Tailscale SSH accepts the SSH protocol's `none` authentication
method after the tailnet policy has identified and authorized the device.

Log in with `sudo tailscale up --ssh`. Enable MagicDNS and HTTPS certificates in
the Tailscale admin console, then run `sudo systemctl restart tailscale-serve`.
Use `tailscale serve status` to find the exact hostname. Use the full
`homelab.<tailnet>.ts.net` hostname, not the short `homelab` name, for valid TLS.

| Application | HTTPS port | Backend (loopback only) |
|---|---:|---:|
| Glance | 443 | 8080 |
| Immich | 8443 | 2283 |
| Vaultwarden | 8444 | 8222 |
| n8n | 8445 | 5678 |
| CouchDB / Obsidian | 8446 | 5984 |
| 9Router | 8447 | 20128 |
| Headroom | 8448 | 8787 |
| Glance dashboard data | 8449 | 8081 |

For example, Immich uses `https://homelab.<tailnet>.ts.net:8443/`, with no `/immich`
suffix. Change the server address in mobile apps and Obsidian. All clients must
be on the tailnet and permitted to access the chosen HTTPS ports by its ACLs.
Public webhook providers cannot reach a tailnet-only n8n endpoint; arrange a
separate, explicitly authorized ingress if public webhooks are needed.

Tailscale Serve generates the dashboard hostname, n8n callback URLs and
Vaultwarden domain under `/run/homelab-urls`, and refreshes those applications.
Serve retries after startup/login failures. Reapply it after renaming the Tailscale node.

Glance uses its native monitor widget to check each backend over loopback. The
service names link to their corresponding Tailscale Serve HTTPS addresses.

## Credentials and NAS migration

`homelab-secrets.service` creates missing credentials on first boot for both
local and remote installations. The standalone installer uses the same script.
Existing nonempty keys are preserved; an empty encryption-key file requires
manual recovery. Secrets are root-owned, mode 0600, inside `/persist/secrets`
(mode 0700), and are not printed. CouchDB reads its password through systemd
credentials. Do not replace n8n's encryption key after storing credentials.

Photo Gallery starts only after you place a real Immich API key in
`/persist/secrets/photo-gallery.env`. Run `sudo systemctl restart photo-gallery`
after editing it. The installer cannot generate an API key for your Immich account.

The NAS stays at `/srv/nas`; no data is moved. Guest access is disabled. Run
`sudo smbpasswd -a kryisnn` to enroll the configured account. New files belong to
the `nas` group and are inaccessible to other local users. Existing guest-created
files may still have the old ownership. To migrate the standard share:

```bash
sudo chgrp -R nas /srv/nas
sudo chmod -R g+rwX,o-rwx /srv/nas
sudo chmod 2770 /srv/nas
```

These commands deliberately change permissions only in the NAS share. Substitute
your configured share path if you changed it. Reconnect SMB clients using the
new account, clearing any cached guest credentials. For another host, set
`homelab.nas.users` and create each account's Samba password.

Vaultwarden registration remains closed on homelab. A fresh installation needs
a deliberate enrollment window: temporarily enable `homelab.vaultwarden.allowSignups`,
create the account over HTTPS, and disable registration again.

## Backups

Homelab backs up daily around 03:00 in its configured Asia/Jakarta timezone to
`/persists/secret`, as requested. This is distinct from `/persist/secrets`, which
contains credentials. Unless the destination is on independent storage, this is
local recovery protection only: it cannot survive disk failure, theft, or a
host compromise. Keep an independent copy of important data and the Restic key.

The backup stops active application writers and PostgreSQL, makes read-only
Btrfs snapshots of `/`, `/persist`, and `/home`, then resumes those services
before uploading. It includes application data under `/var/lib`, the NAS under
`/srv`, home directories, SSH host keys, and `/persist/secrets`. Docker's internal
storage and caches are excluded; the current containers persist through host
bind mounts under `/var/lib`. Newly added services using separate subvolumes,
external mounts or Docker named volumes need their own backup integration.

Restic encrypts the snapshots, retains 7 daily, 4 weekly and 6 monthly restore
points, and checks repository metadata after each run. These checks do not prove
that an application restore works. Staging snapshots are removed after success
or failure; active services are resumed even if snapshot creation fails.

For an external mounted drive, set `homelab.backup.requiredMount` to the drive's
mount point and configure the mount in NixOS. The backup refuses to run when it
is absent. Remote `sftp:` and `s3:` repository URLs are supported; put backend
credentials in the optional `homelab.backup.environmentFile`.

```bash
# Run and inspect a first backup before relying on it.
sudo systemctl start restic-backups-homelab
sudo journalctl -u restic-backups-homelab -n 80 --no-pager
sudo restic-homelab snapshots

# Read all backup data to verify integrity (may take time).
sudo restic-homelab check --read-data

# Restore to a separate directory; never test by overwriting live data.
sudo restic-homelab restore latest --target /var/tmp/homelab-restore-test
```

Restored files are beneath `var/lib/homelab-backup/snapshots/{root,persist,home}`
inside the restore target. Check representative files, then test application
recovery on an isolated host using the same software versions. Stop the target
application before restoring its database/state, preserve ownership, and restore
the corresponding secret files. NixOS rollback does not undo database migrations.

The encryption key is `/persist/secrets/restic-password`. Save it somewhere
independent: the encrypted backup's copy cannot unlock itself after disk loss.

## Resource limits and upgrades

`homelab.lowMemory = true` enables compressed swap, reduces build concurrency,
disables Immich machine learning, and lowers the CPU/I/O priority of n8n and
Immich. Their 1 GiB `MemoryHigh` threshold applies reclaim pressure rather than
a hard kill limit. This is not a guarantee that the entire stack fits in 4 GiB.
Re-enable machine learning explicitly only after checking available RAM.

9Router and Headroom are pinned to verified registry digests. To upgrade, resolve
the new image digest, take a backup, change the pin, build, and check login/API
behavior after switching. OpenHands requires an explicit digest before enabling
and must be deployed on an isolated machine or VM, not re-enabled on this host.

WANE enforces its size bound during live writes. Photo Gallery retains failed
uploads, retries them every five minutes between captures, and expires only
acknowledged uploads. During an extended outage, queued photos can still consume
disk space; check free space and service journals.

## Validation

Run `bash tests/check.sh` and a full system build before deployment. The backup
regressions simulate stop/snapshot failures without touching real services.
Afterwards verify `systemctl --failed`,
HTTPS logins/uploads, an authenticated NAS write, and a separate-directory
backup restore. Local build/tests cannot validate your live Tailscale ACLs or
prove that the backup destination is on an independent disk.
