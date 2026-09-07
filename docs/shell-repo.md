# 🐚 Shell-Repo Service Runner & Private Repository Guide

`shell-repo` is an architectural pattern in Flint NixOS designed for managing custom automation daemons and background scripts at the systemd service level with isolated runtime dependencies—without requiring heavy OCI containerization or formal `nixpkgs` packaging.

---

## 📂 Ecosystem Overview

The `shell-repo/` directory currently hosts three primary automation daemons:

```text
shell-repo/
├── photo-gallery/       # Life Museum 24/7 automated camera capture & Immich sync
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

## 🔒 Why Fork `shell-repo` to a Private Repository?

Separating `shell-repo` into its own private repository is strongly recommended for three reasons:

1. **Security & Privacy:** Automation daemons frequently contain host-specific hardware device nodes (`/dev/video0`), internal IP addresses, camera snapshot endpoints, or personal scheduling preferences that should remain private even if your NixOS dotfiles are public.
2. **Independent Lifecycle:** Your shell automation daemons can be revised, tested, and pushed independently without triggering system-wide NixOS generation rebuilds.
3. **Multi-Host Portability:** A private `shell-repo` can be shared across workstations, laptops, and multiple homelab nodes.

---

## ⚡ Automated Private Forking with `export-shell-repo.sh`

We provide an automated script [`scripts/export-shell-repo.sh`](../scripts/export-shell-repo.sh) that handles the entire extraction, Git initialization, remote push, and optional submodule migration in one step.

### Quick Start:
```bash
# 1. Create an empty PRIVATE repository on GitHub (e.g. 'homelab-shell-repo')
# 2. Run the turnkey exporter:
./scripts/export-shell-repo.sh --repo-url git@github.com:davindakhrisna/homelab-shell-repo.git --mode submodule
```

---

## 🛠️ Manual Forking & Integration Methods

If you prefer to perform the migration manually, choose one of the three architectural approaches below:

---

### Method A: Git Submodule (Recommended)

Keep `shell-repo/` in the same directory path within Flint, but backed by its own private GitHub repository.

#### Step 1: Create the Private Repository on GitHub
1. Navigate to [GitHub -> New Repository](https://github.com/new).
2. Set repository name: `homelab-shell-repo`.
3. Set visibility to **Private**.
4. Leave uninitialized (do not add README or `.gitignore`).

#### Step 2: Extract & Push
```bash
# 1. Copy shell-repo to a temporary workspace
cp -r shell-repo /tmp/shell-repo-export
cd /tmp/shell-repo-export

# 2. Initialize standalone git repo
git init -b main
git add -A
git commit -m "feat: initial export of homelab shell-repo daemons"
git remote add origin git@github.com:davindakhrisna/homelab-shell-repo.git
git push -u origin main
```

#### Step 3: Link Submodule in Flint
Back in your `server-nixos` directory:
```bash
cd ~/Documents/Projects/server-nixos

# 1. Remove untracked shell-repo directory
git rm -r shell-repo

# 2. Add private repository as a submodule
git submodule add git@github.com:davindakhrisna/homelab-shell-repo.git shell-repo

# 3. Commit submodule pointer
git commit -m "refactor(shell-repo): convert shell-repo to private git submodule"
```

> [!IMPORTANT]
> **Working with Submodules in Nix Flakes:**
> By default, Nix flakes do not evaluate git submodules unless explicitly told to do so. Ensure you configure Git to recurse submodules or use the `--submodules` flag:
> ```bash
> git config submodule.recurse true
> nix build --submodules .#nixosConfigurations.homelab.config.system.build.toplevel
> ```

---

### Method B: Standalone Persistent Storage (`/persist/shell-repo`)

If you want your public NixOS configuration to contain **zero traces of `shell-repo` files or submodules**:

1. Clone your private repository directly onto your homelab's persistent storage:
   ```bash
   git clone git@github.com:davindakhrisna/homelab-shell-repo.git /persist/shell-repo
   ```

2. Register the scripts in [`hosts/homelab/default.nix`](../hosts/homelab/default.nix) using `customServices`:

```nix
homelab.shellRepo = {
  enable = true;
  customServices = {
    my-daemon = {
      enable = true;
      script = "/persist/shell-repo/my-daemon/run.sh";
      user = "kryisnn";
      environmentFile = "/persist/secrets/my-daemon.env";
      packages = with pkgs; [ curl jq bash ];
      restartSec = "15s";
    };
  };
};
```

This pattern provides 100% isolation between your public NixOS system configuration and your private automation scripts.

---

### Method C: Flake Input Dependency

You can declare your private repository as a direct Flake input in [`flake.nix`](../flake.nix):

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  shell-repo = {
    url = "git+ssh://git@github.com/davindakhrisna/homelab-shell-repo.git";
    flake = false;
  };
};
```

Then in [`modules/system/services/shell-repo.nix`](../modules/system/services/shell-repo.nix), reference the script directly from the Flake input:
```nix
photoGalleryScript = pkgs.writeShellScriptBin "photo-gallery" (
  builtins.readFile "${inputs.shell-repo}/photo-gallery/photo-gallery.sh"
);
```

---

## 🚀 Adding New Custom Scripts to `shell-repo`

To add a new background daemon:

1. Create a directory `shell-repo/<name>/`.
2. Place your executable script in `shell-repo/<name>/<name>.sh`.
3. Support a continuous loop or `--daemon` argument with clean signal trapping (`SIGTERM`, `SIGINT`).
4. Hook into [`modules/system/services/shell-repo.nix`](../modules/system/services/shell-repo.nix) or [`hosts/homelab/default.nix`](../hosts/homelab/default.nix).
5. Run `nh os switch` to deploy the new background service.
