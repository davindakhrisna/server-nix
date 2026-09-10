# Homelab services

Web services bind to loopback and are accessed through Tailscale Serve. Replace
`<fqdn>` with the full hostname shown by `tailscale serve status`. Each service
has a root URL; path prefixes such as `/immich` are not used.

| Service | Client address | Persistent data | Credentials |
|---|---|---|---|
| Glance | `https://<fqdn>/` | `/var/lib/glance` | Tailnet access; optional dashboard key in `/persist/secrets/glance-dashboard.env` |
| Immich | `https://<fqdn>:8443/` | `/var/lib/immich` and PostgreSQL | Immich account |
| Vaultwarden | `https://<fqdn>:8444/` | `/var/lib/bitwarden_rs` | Vaultwarden account; registration closed |
| n8n | `https://<fqdn>:8445/` | `/var/lib/n8n` (systemd private state) | `/persist/secrets/n8n.env` |
| Obsidian LiveSync / CouchDB | `https://<fqdn>:8446/` | `/var/lib/couchdb` | `/persist/secrets/obsidian-sync-admin-password` |
| 9Router | `https://<fqdn>:8447/` | `/var/lib/9router` | `/persist/secrets/nine-router.env` |
| Headroom | `https://<fqdn>:8448/` | `/var/lib/headroom` | `/persist/secrets/headroom.env` |
| Samba NAS | `smb://<server-ip>/nas` | `/srv/nas` | Local account enrolled with `smbpasswd -a`; no guests |
| OpenHands | Disabled | Existing `/var/lib/openhands` data retained | Use an isolated VM or machine |
| Auto-VC | Background daemon | `/home/kryisnn/.config/config` | Dedicated GitHub deploy key; unchanged |
| WANE | `wane` CLI | `/home/kryisnn/.config/config/wane-log` | Local account |
| Photo Gallery | Background capture and upload | `/var/lib/photo-gallery` | Real Immich API key in `/persist/secrets/photo-gallery.env` |
| Restic backup | Daily around 03:00 | `/persists/secret` destination | `/persist/secrets/restic-password` |

SSH is available only through `tailscale0` and the Tailscale SSH policy; authenticated LAN NAS access remains available. Web backends
are not reachable directly through their old LAN HTTP ports. Tailnet access is
controlled by your Tailscale policies, which are not configured in this repository.

## Secrets

`homelab-secrets.service` provisions missing secrets at boot, without overwriting
existing keys or printing their values. The local installer uses the same helper.
The directory is root-only (0700), with files mode 0600. CouchDB receives its
password through systemd credentials rather than reading a root-only file as
the CouchDB user. Preserve n8n's encryption key across restores.

Photo Gallery's environment file starts with an empty API key because an Immich
account must create it. Until then, the service is skipped. Populate the key and
restart the service. Obsidian's end-to-end encryption is a client configuration
choice; running CouchDB alone does not enable it.

## Isolation and persistence

Glance uses HTTP health checks and does not have Docker socket access.
OpenHands is disabled because Docker engine control belongs on an isolated host.
9Router and Headroom use immutable image digests and loopback port bindings.
Their state persists in host directories independently of container replacement.

Daily encrypted backups capture consistent Btrfs snapshots of application data,
NAS files, home directories and secrets. Local snapshots and a local Restic
destination do not protect against disk failure. An external backup destination
and an independent copy of the encryption key are needed for that protection.

See [Operations and migration](operations.md) for initial account setup, NAS
permissions, backup/restore commands, resource settings and validation.
