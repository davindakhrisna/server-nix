# ❄️ Flint Server - Modular NixOS Homelab

[![NixOS](https://img.shields.io/badge/NixOS-26.05-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![Flake-Parts](https://img.shields.io/badge/Architecture-Flake--Parts-orange.svg)](https://github.com/hercules-ci/flake-parts)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)](#)

A clean, declarative, and robust multi-host NixOS server configuration built with **[flake-parts](https://github.com/hercules-ci/flake-parts)** and **[import-tree](https://github.com/denful/import-tree)**. Optimized for 24/7 homelab operation, AI workloads, automated git synchronization, and headless laptop deployments.

---

## 🏛️ Architecture Overview

```mermaid
graph TD
    subgraph Flint NixOS Flake
        FP[flake-parts / import-tree] --> NM[System Modules]
        FP --> HM[Home Manager Modules]
        FP --> Hosts[Host Configurations]
    end

    subgraph System Services
        NM --> Cloud[Personal Cloud: Immich, Vaultwarden, Obsidian, Samba]
        NM --> AI[AI & Automation: n8n, OpenHands, 9Router, Headroom]
        NM --> SR[Shell-Repo Runner]
    end

    subgraph Shell-Repo Daemons
        SR --> AVC[Auto-VC: 24/7 Git Sync]
        SR --> PG[Photo Gallery: Life Museum]
        SR --> WANE[WANE Watcher: Error Collector]
    end

    subgraph Security & Access
        NM --> TS[Tailscale Mesh & Tailscale SSH]
        NM --> SSH[Hardened OpenSSH]
    end

    subgraph Storage & Hardware
        Hosts --> Disko[Disko Btrfs Subvolumes & Swap]
        Hosts --> Laptop[Headless Laptop Lid-Switch Ignore]
    end
```

---

## ✨ Key Features

- 🏠 **Headless Homelab:** Clean, strictly headless server environment with zero desktop or graphical overhead.
- 💻 **Laptop Server Ready:** Automated lid-switch ignore (`HandleLidSwitch = "ignore"`) and sleep/suspend suppression for 24/7 laptop servers.
- 💾 **Declarative Disko Partitioning:** Reproducible GPT partitioning with ESP (`/boot`), swap, and Btrfs subvolumes (`@`, `@home`, `@nix`, `@persist`, `@log`).
- 🛡️ **OOM & Low-RAM Protection:** Installer immediately enables swap, routes `TMPDIR=/mnt/tmp` to disk, and throttles parallel jobs to prevent out-of-memory crashes on $\le 4\text{GB}$ devices or non-NVMe media.
- 🤖 **AI & Automation Suite:** Declarative native & containerized deployments for **n8n**, **OpenHands**, **9Router**, and **Headroom**.
- 📸 **Media & Cloud Stack:** Production-ready **Immich**, **Glance** dashboard, **Vaultwarden**, **Obsidian LiveSync** (CouchDB), and **Samba NAS**.
- 🔄 **Auto-VC 24/7:** Automated continuous staging, conventional committing, and rebase pushing using dedicated GitHub deploy keys.
- 👁️ **WANE Watcher & CLI:** Real-time warning and error journal watcher with an instant terminal inspector (`wane --show`, `wane --clear`, `wane --status`, `wane --follow`).
- 🐚 **Shell-Repo Runner & Private Forking:** Systemd service runner for custom automation daemons, with turnkey export tooling to keep private scripts in a dedicated private repository.
- 🌐 **Zero-Trust Tailscale:** Automatic peer-to-peer mesh networking and passwordless Tailscale SSH.

---

## 📊 Services & Port Matrix

| Service | Port | Category | Type | Default URL |
| :--- | :--- | :--- | :--- | :--- |
| **Glance Dashboard** | `8080` | Overview & Metrics | Native NixOS | `http://<server-ip>:8080` |
| **Immich** | `2283` | Photos & Video | Native NixOS | `http://<server-ip>:2283` |
| **n8n** | `5678` | Workflow Automation | Native NixOS | `http://<server-ip>:5678` |
| **OpenHands** | `3000` | AI Software Engineer | Docker OCI | `http://<server-ip>:3000` |
| **9Router** | `20128` | LLM Gateway & Router | Docker OCI | `http://<server-ip>:20128` |
| **Headroom** | `8787` | Context Compression | Docker OCI | `http://<server-ip>:8787` |
| **Vaultwarden** | `8222` | Password Manager | Native NixOS | `http://<server-ip>:8222` |
| **Obsidian LiveSync**| `5984` | Note Synchronization | Native CouchDB | `http://<server-ip>:5984` |
| **Samba NAS** | `139, 445` | Local Storage | Native Samba | `smb://<server-ip>/` |
| **Auto-VC** | N/A | Git Automation | Systemd Daemon | Terminal / Git Remote |
| **WANE Watcher** | N/A | Log Inspection | Systemd Daemon | CLI: `wane --show` |

*For storage paths, environment files, and service configuration options, see the [Services Guide](docs/services.md).*

---

## 📚 Documentation Index

| Guide | Description |
| :--- | :--- |
| [💾 Installation & Deployment](docs/installation.md) | Complete step-by-step guide for bare-metal, low-RAM, non-NVMe, and remote installations |
| [🛠️ Services Architecture & Matrix](docs/services.md) | Full breakdown of all homelab services, ports, data persistence, and secrets |
| [🔄 Auto-VC 24/7 Guide](docs/auto-vc-guide.md) | Automated Git add, commit, and push daemon setup and CLI commands |
| [👁️ WANE Watcher & CLI Guide](docs/wane-guide.md) | System warning & error journal monitor, log rotation, and `wane` commands |
| [🐚 Shell-Repo & Private Repo Guide](docs/shell-repo.md) | Shell service runner overview and instructions for forking `shell-repo` into a private repo |
| [📦 Adding New Services](docs/adding-services.md) | Developer guide for adding native NixOS services or declarative OCI containers |

---

## 🚀 Quick Commands

```bash
# 1. Bare-metal Wipe & Install (from Live USB)
sudo ./install.sh --disk /dev/nvme0n1 --host homelab

# 2. Remote Deployment over SSH (nixos-anywhere)
./install.sh --mode remote --host homelab --target root@<homelab-ip> --disk /dev/sda

# 3. Post-Installation Setup (GitHub 24/7 Deploy Key & Tailscale)
./post-install.sh

# 4. Fork shell-repo into a Private Repository
./scripts/export-shell-repo.sh --repo-url git@github.com:davindakhrisna/homelab-shell-repo.git --mode submodule

# 5. Inspect System Warnings & Errors
wane --show 20 desc all
wane --status

# 6. Rebuild System after Config Changes
nh os switch

# 7. Check & Lint Nix Flake
nix flake check --impure
nix run nixpkgs#alejandra -- .
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- .
```

---

## 🔒 Private Repository Recommendation

`shell-repo/` contains your personal automation daemons, camera configurations, and host-specific scripts. We strongly recommend forking `shell-repo` into a private Git repository to keep sensitive paths and hardware nodes separate from your main NixOS configuration.

Follow our [Shell-Repo Private Repo Guide](docs/shell-repo.md) or run:
```bash
./scripts/export-shell-repo.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
