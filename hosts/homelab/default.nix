{
  self,
  inputs,
  ...
}: {
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
      ({pkgs, ...}: {
        networking.hostName = "homelab";
        time.timeZone = "Asia/Jakarta";
        i18n.defaultLocale = "en_US.UTF-8";

        # User Account (System-level)
        users.users.kryisnn = {
          isNormalUser = true;
          shell = pkgs.zsh;
          extraGroups = [
            "wheel"
            "networkmanager"
            "docker"
            "video"
          ];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJH9jDDmY066+eqWJq6HZtJuhysL3CAL29HsSM1rtSou kris@windows"
          ];
        };

        # Homelab Services Suite
        homelab = {
          lowMemory = true;
          backup = {
            enable = true;
            repository = "/persists/secret";
            # A folder on the system disk does not protect against disk failure.
            # Set requiredMount when using an external backup disk.
          };
          ssh = {
            enable = true;
            tailscaleSshUsers = ["arpeggio.gns@gmail.com"];
            tailscaleSshTargetUser = "kryisnn";
          };
          immich.enable = true;
          glance = {
            enable = true;
            dashboardDataPort = 8081;
            dashboardEnvironmentFile = "/persist/secrets/glance-dashboard.env";
            bookmarks = [
              {
                title = "Homelab Services";
                links = [
                  {
                    title = "Immich Photos";
                    backendPort = 2283;
                  }
                  {
                    title = "Vaultwarden";
                    backendPort = 8222;
                  }
                  {
                    title = "Obsidian CouchDB";
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
                    backendPort = 5678;
                  }
                  {
                    title = "9Router";
                    backendPort = 20128;
                  }
                  {
                    title = "Headroom";
                    backendPort = 8787;
                  }
                ];
              }
              {
                title = "Quality of Life";
                links = [];
              }
              {
                title = "Learning Resources";
                links = [];
              }
            ];
            monitoredServices = [
              {
                title = "Glance";
                url = "http://127.0.0.1:8080";
              }
              {
                title = "n8n";
                url = "http://127.0.0.1:5678";
              }
              {
                title = "Immich";
                url = "http://127.0.0.1:2283";
              }
              {
                title = "Vaultwarden";
                url = "http://127.0.0.1:8222";
              }
              {
                title = "Obsidian Sync";
                url = "http://127.0.0.1:5984";
              }
              {
                title = "9Router";
                url = "http://127.0.0.1:20128";
              }
              {
                title = "Headroom";
                url = "http://127.0.0.1:8787/health";
              }
            ];
            photoSource = {
              directory = "/var/lib/photo-gallery/captures";
              immichBackendPort = 2283;
            };
            nineRouterUrl = "http://127.0.0.1:20128";
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
              "8449" = 8081;
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
              cameraDevice = "/dev/video2";
              environmentFile = "/persist/secrets/photo-gallery.env";
            };
            autoVc = {
              enable = true;
              repoPath = "/home/kryisnn/.config/config";
              intervalSeconds = 60;
            };
            waneWatcher = {
              enable = true;
              logFile = "/home/kryisnn/.config/config/wane-log";
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
          flakePath = "/home/kryisnn/.config/config"; # Path to your flake repository
          cpu = "intel";
          gpu = null; # Set to "nvidia", "amd", or "intel" if laptop has dedicated GPU
          dualBoot.enable = false;
        };

        # User Configuration (Home Manager level)
        home-manager.users.kryisnn = {...}: {
          imports = with self.homeModules; [
            home-manager
            shell
            dev
          ];
        };

        system.stateVersion = "26.05";
      })
    ];
  };
}
