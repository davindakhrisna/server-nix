{
  self,
  inputs,
  ...
}: let
  publicDefaults = import ./_local.example.nix;
  localOverrides =
    if builtins.pathExists ./_local.nix
    then import ./_local.nix
    else {};
  host = publicDefaults // localOverrides;
in {
  flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {inherit inputs self;};
          backupFileExtension = "backup";
          sharedModules = [
            inputs.nvf.homeManagerModules.default
          ];
        };
      }

      # System modules (base, hardware, utils, homelab services)
      self.nixosModules.system

      # Host-specific Configuration
      ({lib, pkgs, ...}: {
        networking.hostName = host.hostName;
        time.timeZone = host.timeZone;
        i18n.defaultLocale = "en_US.UTF-8";

        # User Account (System-level)
        users.users.${host.primaryUser} = {
          isNormalUser = true;
          uid = host.primaryUid;
          shell = pkgs.zsh;
          extraGroups = [
            "wheel"
            "networkmanager"
            "docker"
            "video"
          ];
          openssh.authorizedKeys.keys = host.sshAuthorizedKeys;
        };

        # Homelab Services Suite
        homelab = {
          lowMemory = true;
          backup = {
            enable = true;
            repository = host.backupRepository;
            # A folder on the system disk does not protect against disk failure.
            # Set requiredMount when using an external backup disk.
          };
          ssh = {
            enable = true;
            tailscaleSshUsers = host.tailscaleSshUsers;
            tailscaleSshTargetUser =
              if host.tailscaleSshUsers == []
              then null
              else host.primaryUser;
          };
          immich.enable = true;
          glance = {
            enable = true;
            weatherLocation = host.weatherLocation;
            bookmarks = [
              {
                title = "Homelab Services";
                links = [
                  {
                    title = "Immich Photos";
                    icon = "si:immich";
                    backendPort = 2283;
                  }
                  {
                    title = "Vaultwarden";
                    icon = "si:vaultwarden";
                    backendPort = 8222;
                  }
                  {
                    title = "Obsidian CouchDB";
                    icon = "si:apachecouchdb";
                    backendPort = 5984;
                    path = "/_utils";
                  }
                ];
              }
              {
                title = "AI & Automation";
                links = [
                  {
                    title = "n8n Workflows";
                    icon = "si:n8n";
                    backendPort = 5678;
                  }
                  {
                    title = "9Router";
                    icon = "/assets/9router.svg";
                    backendPort = 20128;
                  }
                  {
                    title = "Headroom";
                    icon = "/assets/headroom.svg";
                    backendPort = 8787;
                  }
                ];
              }
            ];
            monitoredServices = [
              {
                title = "Glance";
                icon = "sh:glance";
                backendPort = 8080;
                checkUrl = "http://127.0.0.1:8080";
              }
              {
                title = "n8n";
                icon = "si:n8n";
                backendPort = 5678;
                checkUrl = "http://127.0.0.1:5678";
              }
              {
                title = "Immich";
                icon = "si:immich";
                backendPort = 2283;
                checkUrl = "http://127.0.0.1:2283";
              }
              {
                title = "Vaultwarden";
                icon = "si:vaultwarden";
                backendPort = 8222;
                checkUrl = "http://127.0.0.1:8222";
              }
              {
                title = "Obsidian Sync";
                icon = "si:apachecouchdb";
                backendPort = 5984;
                path = "/_utils";
                checkUrl = "http://127.0.0.1:5984";
              }
              {
                title = "9Router";
                icon = "/assets/9router.svg";
                backendPort = 20128;
                checkUrl = "http://127.0.0.1:20128";
              }
              {
                title = "Headroom";
                icon = "/assets/headroom.svg";
                backendPort = 8787;
                checkUrl = "http://127.0.0.1:8787/health";
              }
            ];
          };

          # Each application gets a root URL on its own HTTPS port.
          # Requires Tailscale login, MagicDNS and HTTPS certificates.
          tailscaleServe = {
            enable = true;
            routes = {
              "443" = 8080;
              "8443" = 2283;
              "8444" = 8222;
              "8445" = 5678;
              "8446" = 5984;
              "8447" = 20128;
              "8448" = 8787;
            };
          };
          vaultwarden = {
            enable = true;
            # Close open registration once your account exists
            allowSignups = false;
          };
          nas.enable = true;
          obsidianSync = {
            enable = true;
            adminUser = "admin";
            # Password read at runtime from this file (generated by install.sh)
            adminPasswordFile = "/persist/secrets/obsidian-sync-admin-password";
          };

          shellRepo = {
            enable = true;
            photoGallery = {
              enable = true;
              cameraType = "usb";
              cameraDevice = host.cameraDevice;
              albumName = host.photoAlbumName;
              albumDescription = host.photoAlbumDescription;
              deviceId = host.photoDeviceId;
              environmentFile = "/persist/secrets/photo-gallery.env";
            };
            autoVc = {
              enable = host.autoVcEnable;
              repoPath = host.repoPath;
              intervalSeconds = 60;
            };
            waneWatcher = {
              enable = true;
            };
          };

          # AI & Automation Services Suite
          n8n = {
            enable = true;
            # Pins N8N_ENCRYPTION_KEY so stored credentials survive rebuilds
            environmentFile = "/persist/secrets/n8n.env";
          };
          openhands = {
            # Keep AI execution off this host until a separate VM is available.
            enable = false;
            environmentFile = "/persist/secrets/openhands.env";
          };
          nineRouter = {
            enable = true;
            # 9router login password (default is 123456 - see its docs)
            environmentFile = "/persist/secrets/nine-router.env";
          };
          headroom = {
            enable = true;
            # Auth token for the /v1/* proxy routes (open port otherwise)
            environmentFile = "/persist/secrets/headroom.env";
          };
        };

        # Hardware & Flake Path
        var = {
          primaryUser = host.primaryUser;
          flakePath = host.flakePath;
          cpu = "intel";
          gpu = null; # Set to "nvidia", "amd", or "intel" if laptop has dedicated GPU
          dualBoot.enable = false;
        };

        # User Configuration (Home Manager level)
        home-manager.users.${host.primaryUser} = {...}: {
          imports = with self.homeModules; [
            home-manager
            shell
            dev
          ];
          programs.git.settings.user = lib.mkIf (host.git.name != null && host.git.email != null) {
            inherit (host.git) name email;
          };
        };

        system.stateVersion = "26.05";
      })
    ];
  };
}
