# 🐚 Shell-Repo Service Runner Guide

`shell-repo` is an architectural pattern in this NixOS server configuration designed for managing custom automation daemons and background scripts at the systemd service level with isolated runtime dependencies—without requiring heavy OCI containerization or formal `nixpkgs` packaging.

---

## 📂 Ecosystem Overview

The `shell-repo/` directory in this repository hosts three primary automation daemons:

```text
shell-repo/
├── photo-gallery/       # Automated camera capture & Immich sync
│   ├── photo-gallery.sh
│   ├── .env.example
│   └── README.md
├── auto-vc/             # 24/7 automated Git add, commit & push daemon
│   ├── auto-vc.sh
│   ├── .env.example
│   └── README.md
└── wane-watcher/        # 24/7 system warning & error journal watcher and CLI
    ├── wane.sh
    ├── .env.example
    └── README.md
```

Each script runs as an isolated, self-healing systemd service (`Restart = "always"`) managed through [`modules/system/services/shell-repo.nix`](../modules/system/services/shell-repo.nix).

---

## 🤖 The Three Built-in Daemons

### 1. 🔄 Auto-VC (`shell-repo/auto-vc/`)
- **Purpose:** 24/7 continuous Git version control.
- **How it works:** Periodically checks your repository for changes, stages them (`git add -A`), generates timestamped conventional commit messages, rebases against remote, and pushes cleanly via a dedicated SSH deploy key.
- **Service:** `auto-vc.service`
- **CLI Commands:**
  ```bash
  ./shell-repo/auto-vc/auto-vc.sh --status
  ./shell-repo/auto-vc/auto-vc.sh --dry-run
  ./shell-repo/auto-vc/auto-vc.sh --run-once
  ```
- *See [Auto-VC Guide](auto-vc-guide.md) for full details.*

### 2. 📸 Photo Gallery (`shell-repo/photo-gallery/`)
- **Purpose:** Automated camera capture & Immich synchronization.
- **How it works:** Wakes USB webcams (`/dev/video0`) or RTSP/HTTP streams at randomized intervals during daytime hours, captures high-resolution frames with ffmpeg, and uploads them directly into an Immich album.
- **Service:** `photo-gallery.service`
- **Configuration:** Set environment variables or secrets in `/persist/secrets/photo-gallery.env`.

### 3. 👁️ WANE Watcher (`shell-repo/wane-watcher/`)
- **Purpose:** 24/7 system warning & error journal collector and CLI inspector.
- **How it works:** Continuously filters `systemd` journal entries for levels 0–4 (`emerg`, `alert`, `crit`, `err`, `warning`), writing structured logs to a central `wane-log` file with automatic rotation.
- **Service:** `wane-watcher.service`
- **CLI Commands:**
  ```bash
  wane --show 20 desc all
  wane --status
  wane --clear
  wane --follow
  ```
- *See [WANE Guide](wane-guide.md) for full details.*

---

## 🛠️ Adding New Custom Scripts to `shell-repo`

You can add arbitrary new daemons directly to this configuration without writing raw systemd unit files:

### Method 1: Using `customServices`
In [`hosts/homelab/default.nix`](../hosts/homelab/default.nix):

```nix
homelab.shellRepo = {
  enable = true;
  customServices = {
    my-backup = {
      enable = true;
      script = "/path/to/config/shell-repo/my-script.sh";
      user = "operator";
      environmentFile = "/persist/secrets/my-script.env";
      packages = with pkgs; [ rsync curl jq bash ];
      restartSec = "30s";
    };
  };
};
```

### Method 2: Adding a Built-in Module Option
1. Create `shell-repo/<daemon-name>/<daemon-name>.sh`.
2. Add the option to [`modules/system/services/shell-repo.nix`](../modules/system/services/shell-repo.nix) using `pkgs.writeShellScriptBin`.
3. Enable it in [`hosts/homelab/default.nix`](../hosts/homelab/default.nix).
4. Apply changes with `nh os switch`.
