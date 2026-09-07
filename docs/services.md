# 🛠️ Services Matrix & Architecture Guide

Flint NixOS deploys a curated, unified homelab suite across AI workflows, automation, self-hosted cloud, and system intelligence.

---

## 📊 Homelab Service Port & Storage Matrix

| Service | Port | Protocol / Type | Default URL | Persistent Storage | Secrets / Env File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Glance** | `8080` | Native NixOS | `http://<server-ip>:8080` | `/var/lib/glance` | N/A |
| **Immich** | `2283` | Native NixOS | `http://<server-ip>:2283` | `/var/lib/immich` | N/A |
| **n8n** | `5678` | Native NixOS | `http://<server-ip>:5678` | `/var/lib/n8n` | `/persist/secrets/n8n.env` |
| **OpenHands** | `3000` | Docker OCI | `http://<server-ip>:3000` | `/var/lib/openhands/workspace` | Docker socket mounted |
| **9Router** | `20128` | Docker OCI | `http://<server-ip>:20128` | `/var/lib/9router` | `/persist/secrets/9router.env` |
| **Headroom** | `8787` | Docker OCI | `http://<server-ip>:8787` | Stateless container | N/A |
| **Vaultwarden** | `8222` | Native NixOS | `http://<server-ip>:8222` | `/var/lib/bitwarden_rs` | `/persist/secrets/vaultwarden.env` |
| **Obsidian LiveSync** | `5984` | Native CouchDB | `http://<server-ip>:5984` | `/var/lib/couchdb` | In flake / CouchDB local.ini |
| **Samba NAS** | `139, 445`| Native Samba | `smb://<server-ip>/` | `/persist/storage` | User samba credentials |
| **Auto-VC** | N/A | Systemd Daemon | Git CLI (`origin main`) | `/home/kryisnn/.config/flint` | `~/.ssh/id_github_deploy` |
| **WANE Watcher** | N/A | Systemd Daemon | Terminal (`wane`) | `/home/kryisnn/.config/flint/wane-log` | N/A |
| **Photo Gallery** | N/A | Systemd Daemon | Syncs to Immich | `/var/lib/photo-gallery` | `/persist/secrets/photo-gallery.env` |

---

## 🏛️ Service Implementation Categories

### 1. AI & Workflow Automation Stack

#### ⚡ n8n (Native NixOS)
- **Port:** `5678`
- **Module:** [`modules/system/services/n8n.nix`](../modules/system/services/n8n.nix)
- **Features:** Self-hosted workflow automation platform connecting APIs, webhooks, and AI models. Runs natively with minimal overhead and auto-starts on boot.
- **Config:**
  ```nix
  homelab.n8n = {
    enable = true;
    port = 5678;
  };
  ```

#### 🤖 OpenHands (Declarative Docker OCI)
- **Port:** `3000`
- **Module:** [`modules/system/services/openhands.nix`](../modules/system/services/openhands.nix)
- **Features:** Autonomous AI software engineer capable of writing code, running bash commands, and building web apps. Configured with Docker socket passthrough (`/var/run/docker.sock`) to spawn runtime micro-containers safely.
- **Config:**
  ```nix
  homelab.openhands = {
    enable = true;
    port = 3000;
    workspaceDir = "/var/lib/openhands/workspace";
  };
  ```

#### 🔀 9Router (Declarative Docker OCI)
- **Port:** `20128`
- **Module:** [`modules/system/services/nine-router.nix`](../modules/system/services/nine-router.nix)
- **Features:** High-performance LLM proxy and intelligent router for OpenAI, Anthropic, Gemini, and local model backends.
- **Config:**
  ```nix
  homelab.nineRouter = {
    enable = true;
    port = 20128;
    dataDir = "/var/lib/9router";
  };
  ```

#### 🧠 Headroom (Declarative Docker OCI)
- **Port:** `8787`
- **Module:** [`modules/system/services/headroom.nix`](../modules/system/services/headroom.nix)
- **Features:** Real-time semantic compression and context-window optimizer for AI agents and LLM APIs.
- **Config:**
  ```nix
  homelab.headroom = {
    enable = true;
    port = 8787;
  };
  ```

---

### 2. Media & Personal Cloud Stack

#### 📸 Immich & Photo Gallery
- **Immich:** Native photo management suite with automatic facial recognition, object detection, and high-performance indexing on port `2283`.
- **Photo Gallery Daemon:** Custom Life Museum daemon that triggers USB webcams or RTSP cameras at randomized daytime intervals and syncs captures directly into Immich.

#### 🪟 Glance Dashboard
- **Port:** `8080`
- **Module:** [`modules/system/services/glance.nix`](../modules/system/services/glance.nix)
- **Features:** Minimalist, high-density dashboard displaying server metrics (CPU, Memory, Disk), Twitch/YouTube feeds, RSS feeds, and bookmarks for all running homelab services.

#### 🔐 Vaultwarden
- **Port:** `8222`
- **Features:** Lightweight, Bitwarden-compatible password vault with Argon2id encryption.

#### 📝 Obsidian LiveSync
- **Port:** `5984`
- **Features:** End-to-end encrypted real-time bi-directional synchronization for Obsidian note vaults powered by CouchDB.

#### 📁 Samba NAS
- **Ports:** `139`, `445`
- **Features:** Cross-platform file sharing for macOS, Windows, Linux, and mobile devices with persistent storage on Btrfs subvolumes.

---

## 🔒 Secrets Management Pattern

Sensitive API keys, database passwords, and auth tokens should **never** be committed to Git. Flint uses systemd `EnvironmentFile` paths residing on persistent storage:

```text
/persist/secrets/
├── n8n.env
├── 9router.env
├── photo-gallery.env
└── vaultwarden.env
```

Ensure correct file permissions on your secrets:
```bash
sudo mkdir -p /persist/secrets
sudo chmod 700 /persist/secrets
sudo chown root:root /persist/secrets
```
