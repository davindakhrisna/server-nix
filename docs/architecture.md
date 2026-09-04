# ❄️ Flint NixOS Configuration - Architecture & Overview

Flint is a modular, multi-host NixOS configuration built with **Flake-Parts** and **Import-Tree** for clean modularity, declarative hardware abstraction, and tiered development profiles.

---

## 📁 Repository Structure

```
.
├── flake.nix                  # Flake definition with inputs and flake-parts root
├── flake.lock                 # Pinned dependencies lockfile
├── docs/                      # Documentation
│   ├── architecture.md
│   └── offline-installation.md
├── hosts/                     # Machine-specific host configurations
│   ├── powerhouse/            # Primary homelab server configuration
│   │   ├── _hardware.nix      # Disk mounts and hardware scan definitions
│   │   └── default.nix        # Host entrypoint & user declarations
│   └── template/              # Ready-to-use template for new machines
│       ├── _hardware.nix
│       └── default.nix
└── modules/                   # Shared modular components
    ├── home/                  # Home Manager modules (Headless)
    │   ├── dev/               # Unified developer tools (Neovim nvf, compilers, Go, Node, Python)
    │   ├── shell/             # Zsh, modern CLI tools
    │   └── home.nix           # Base Home Manager & XDG compliance rules
    └── system/                # NixOS System-level modules
        ├── base.nix           # Headless base, laptop lid tweaks, Docker, Tailscale, DNS
        ├── default.nix        # Core system modules bundle
        ├── hardware.nix       # CPU (Intel/AMD) & GPU abstractions
        ├── utils.nix          # System-wide CLI utilities and diagnostic tools
        └── services/          # Modular homelab service suite
            ├── default.nix    # Services bundle
            ├── ssh.nix        # Hardened OpenSSH & Tailscale SSH
            ├── immich.nix     # Immich photo & video management
            ├── glance.nix     # Glance homelab dashboard
            ├── vaultwarden.nix# Bitwarden-compatible password manager
            ├── obsidian-sync.nix # CouchDB for Obsidian LiveSync
            └── nas.nix        # Samba NAS, WSDD & Avahi mDNS discovery
```

---

## ⚙️ Key Architectural Features

### 1. Laptop Server Resiliency
- **Lid Switch Management:** Configured via `services.logind.settings.Login` (`HandleLidSwitch = "ignore"`) to ensure closing the laptop lid never suspends the system.
- **Sleep/Suspend Suppression:** Disables systemd sleep, suspend, hibernate, and hybrid-sleep targets.

### 2. Tailscale & Zero-Password SSH
- **Tailscale SSH:** Automated with `tailscale up --ssh`. Devices signed into your Tailnet authenticate seamlessly without password prompts.
- **OpenSSH Hardening:** Passwords and root login are forbidden; authentication relies strictly on SSH public keys or Tailscale cryptographic keys.
- **Local LAN Direct Connection:** Direct peer-to-peer connection over local Wi-Fi with zero internet relay and full LAN speeds.

### 3. Declarative Homelab Services Suite
Toggle individual services per host under the `homelab.*` option namespace:
- `homelab.immich.enable`: Port 2283 with storage in `/var/lib/immich`.
- `homelab.glance.enable`: Port 5678 dashboard with service bookmarks and clock.
- `homelab.vaultwarden.enable`: Port 8222 lightweight password vault.
- `homelab.obsidianSync.enable`: Port 5984 CouchDB instance preconfigured with CORS and document size settings for Obsidian LiveSync.
- `homelab.nas.enable`: Samba share at `/srv/nas` with Windows WSDD and Apple Avahi mDNS auto-discovery.

### 4. Developer Tools & Neovim (`dev`)
Includes headless developer tooling directly within your user environment:
- C/C++ toolchain (`gcc`, `gnumake`, `pkg-config`), SQLite CLI.
- Web & backend runtimes: Go, Node.js, Python 3, `pnpm`, and `air`.
- Container & debugging utilities: `lazydocker`, `netcat-gnu`.
- Git workflow: `git`, `gh` (credential helper), `direnv`, `lazygit`, and formatting tools (`alejandra`, `nixfmt`).
- Fully customized terminal Neovim via `nvf` with custom OLED theme, LSP, Treesitter, and custom keymaps.

### 5. DNS & Network Configuration
Default network configurations automatically set Quad9 DNS:
- Primary: `9.9.9.9`
- Secondary: `149.112.112.112`
- NetworkManager automatically prioritizes these nameservers across all network interfaces.

### 6. XDG Compliance & Dotfile Cleanliness
Strict adherence to the XDG Base Directory specification:
- Cargo, Rustup, Go, NPM, Gradle, and Android directories are redirected to `~/.local/share` and `~/.cache`.
- Legacy dotfiles (`.zshenv`, `.gtkrc-2.0`) in `$HOME` root are disabled or relocated to keep the user home directory clean.

---

## 🧪 Validation & Linting Commands

Run validation checks directly using the following commands:

```bash
# 1. Format code
nix run nixpkgs#alejandra -- .

# 2. Check for dead/unused code
nix run nixpkgs#deadnix -- .

# 3. Check for anti-patterns and style suggestions
nix run nixpkgs#statix -- check .

# 4. Dry evaluation (validate configuration logic without building)
nix eval .#nixosConfigurations.powerhouse.config.system.build.toplevel.drvPath
```
