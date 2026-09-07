# 📦 Adding New Services to Flint NixOS

This guide explains how to add new services to this server configuration using our modular architecture built with **[flake-parts](https://github.com/hercules-ci/flake-parts)** and **[import-tree](https://github.com/denful/import-tree)**.

---

## 🏛️ Architecture Overview

Services are structured as independent, self-contained NixOS modules under [`modules/system/services/`](../modules/system/services/):

```text
modules/system/services/
├── default.nix          # Master registry importing all service modules
├── immich.nix           # Native NixOS service pattern
├── glance.nix           # Dashboard & bookmarks
├── n8n.nix              # Native NixOS systemd service pattern
├── openhands.nix        # OCI container with Docker socket mount
├── nine-router.nix      # OCI container with volume persistence
├── headroom.nix         # OCI container proxy pattern
└── shell-repo.nix       # Shell-repo background daemon runner
```

There are two primary ways to deploy a service on Flint:
1. **Native NixOS Services** (when the package exists in `nixpkgs`).
2. **Declarative OCI Containers** (for container-first applications via Docker).

---

## 🛠️ Pattern 1: Native NixOS Service

Use this pattern when the service has built-in NixOS support in `nixpkgs` (e.g., `services.vaultwarden`, `services.n8n`, `services.immich`).

### 1. Create `modules/system/services/myservice.nix`:

```nix
{
  flake.nixosModules.services-myservice = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.myservice;
  in {
    options.homelab.myservice = {
      enable = lib.mkEnableOption "MyService description";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port on which MyService listens";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open port in firewall";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file containing secrets";
      };
    };

    config = lib.mkIf cfg.enable {
      services.myservice = {
        enable = true;
        port = cfg.port;
      };

      # Pass secrets via systemd EnvironmentFile if configured
      systemd.services.myservice = lib.mkIf (cfg.environmentFile != null) {
        serviceConfig.EnvironmentFile = cfg.environmentFile;
      };

      # Open firewall port if enabled
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
    };
  };
}
```

---

## 🐳 Pattern 2: Declarative OCI Container (Docker)

Use this pattern for containerized services not packaged in `nixpkgs` (e.g., `openhands`, `9router`, `headroom`).

### 1. Create `modules/system/services/mycontainer.nix`:

```nix
{
  flake.nixosModules.services-mycontainer = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.mycontainer;
  in {
    options.homelab.mycontainer = {
      enable = lib.mkEnableOption "MyContainer description";

      port = lib.mkOption {
        type = lib.types.port;
        default = 9000;
        description = "Port on which MyContainer listens";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/myorg/mycontainer:latest";
        description = "Container image";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/mycontainer";
        description = "Persistent data directory on host";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open port in firewall";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file for secrets";
      };
    };

    config = lib.mkIf cfg.enable {
      # Ensure data directory exists with correct permissions
      systemd.tmpfiles.rules = [
        "d ${toString cfg.dataDir} 0750 root root -"
      ];

      virtualisation.oci-containers = {
        backend = lib.mkDefault "docker";
        containers.mycontainer = {
          inherit (cfg) image;
          autoStart = true;
          ports = [
            "${toString cfg.port}:9000"
          ];
          volumes = [
            "${toString cfg.dataDir}:/app/data"
          ];
          environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
    };
  };
}
```

---

## 🔗 Step 3: Register in Module Index

Add your new module export to [`modules/system/services/default.nix`](../modules/system/services/default.nix):

```nix
{
  flake.nixosModules.services = {self, ...}: {
    imports = with self.nixosModules; [
      services-ssh
      services-immich
      services-glance
      services-vaultwarden
      services-obsidian-sync
      services-nas
      services-shell-repo
      services-n8n
      services-openhands
      services-nine-router
      services-headroom
      services-myservice # <-- Add here
    ];
  };
}
```

---

## 🖥️ Step 4: Add to Glance Dashboard (Optional)

In [`modules/system/services/glance.nix`](../modules/system/services/glance.nix), add a quick bookmark under the `bookmarks` widget:

```nix
{
  title = "My Service";
  url = "http://localhost:8080";
}
```

---

## 🚀 Step 5: Enable on Host

Activate the service on your host configuration in [`hosts/homelab/default.nix`](../hosts/homelab/default.nix):

```nix
homelab = {
  myservice.enable = true;
};
```

---

## 🧪 Step 6: Test & Build

Test evaluation and rebuild without switching:

```bash
# 1. Check syntax and formatting
nix run nixpkgs#alejandra -- .
nix run nixpkgs#statix -- check .

# 2. Evaluate system derivation
nix eval .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath

# 3. Dry build
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --dry-run

# 4. Apply changes
nh os switch
```
