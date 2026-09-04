# ❄️ Flint - Multi-host NixOS Configuration

A clean, modular, and performant multi-host NixOS configuration built with [flake-parts](https://github.com/hercules-ci/flake-parts) and [import-tree](https://github.com/denful/import-tree).

---

## ✨ Features

- 🏠 **Headless Homelab:** Clean, strictly headless server environment with zero GUI/desktop baggage.
- 💻 **Laptop Server Ready:** Automated lid-switch ignore (`HandleLidSwitch = "ignore"`) and sleep/suspend suppression for uninterrupted operation on laptops.
- 📦 **Homelab Services Stack:** Declarative native services for **Immich** (photos), **Glance** (dashboard), **Vaultwarden** (Bitwarden password manager), **Obsidian LiveSync** (CouchDB), and **Samba NAS** (with Windows WSDD and Apple Avahi mDNS discovery).
- 🌐 **Automated Tailscale & Tailscale SSH:** Direct peer-to-peer Wi-Fi connectivity and zero-password SSH access for devices authenticated to your Tailscale account.
- 🛠️ **Terminal & Developer Experience:** Gorgeous OLED monochrome Neovim (`nvf`), Zsh vi-mode with FZF integration, modern CLI replacements (`eza`, `bat`, `duf`, `ripgrep`, `zoxide`), and Docker.
- 🧹 **100% XDG Compliant:** Clean `$HOME` with all histories and tool states routed to standard XDG directories.

---

## 📚 Documentation

- [📦 Offline Installation Guide](docs/offline-installation.md)
- [🏛️ Architecture & Module Structure](docs/architecture.md)

---

## 🚀 Quick Commands

```bash
# Validate and evaluate configuration
nix eval .#nixosConfigurations.powerhouse.config.system.build.toplevel.drvPath

# Rebuild system using Nix Helper (nh)
nh os switch

# Format & Lint
nix run nixpkgs#alejandra -- .
nix run nixpkgs#deadnix -- .
nix run nixpkgs#statix -- check .
```
