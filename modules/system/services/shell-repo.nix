{
  flake.nixosModules.services-shell-repo = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.homelab.shellRepo;

    photoGalleryScript = pkgs.writeShellScriptBin "photo-gallery" (
      builtins.readFile ../../../shell-repo/photo-gallery/photo-gallery.sh
    );
  in {
    options.homelab.shellRepo = {
      enable = lib.mkEnableOption "Shell-Repo service runner for custom background scripts";

      photoGallery = {
        enable = lib.mkEnableOption "Photo Gallery (Life Museum) automated capture and Immich sync daemon";

        user = lib.mkOption {
          type = lib.types.str;
          default = "kryisnn";
          description = "User to run the photo-gallery daemon as";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
          default = null;
          description = "Path to environment file containing sensitive secrets (e.g., IMMICH_API_KEY)";
        };

        immichUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:2283";
          description = "URL of the Immich instance";
        };

        albumName = lib.mkOption {
          type = lib.types.str;
          default = "Life Museum";
          description = "Target Immich album name for daily captures";
        };

        cameraType = lib.mkOption {
          type = lib.types.enum ["usb" "rtsp" "http" "rpi" "custom"];
          default = "usb";
          description = "Camera input type";
        };

        cameraDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/video0";
          description = "Device node for USB webcam (used when cameraType is 'usb')";
        };

        cameraResolution = lib.mkOption {
          type = lib.types.str;
          default = "1920x1080";
          description = "Capture resolution in WIDTHxHEIGHT format";
        };

        cameraWarmupSeconds = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Delay in seconds to allow camera auto-exposure and white balance to adjust";
        };

        cameraStreamUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Stream/snapshot URL (used when cameraType is 'rtsp' or 'http')";
        };

        scheduleMode = lib.mkOption {
          type = lib.types.enum ["random_daily" "random_hourly" "random_interval"];
          default = "random_daily";
          description = "Schedule mode for photo captures";
        };

        windowStartHour = lib.mkOption {
          type = lib.types.int;
          default = 8;
          description = "Start hour of active daytime window (0-23)";
        };

        windowEndHour = lib.mkOption {
          type = lib.types.int;
          default = 22;
          description = "End hour of active daytime window (0-23)";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/photo-gallery";
          description = "Directory for storing captures and capture state";
        };
      };

      customServices = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "Custom shell service";

              script = lib.mkOption {
                type = lib.types.either lib.types.path lib.types.str;
                description = "Path to executable shell script or binary";
              };

              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Arguments passed to script";
              };

              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [];
                description = "Runtime packages to inject into service PATH";
              };

              user = lib.mkOption {
                type = lib.types.str;
                default = "root";
                description = "User to run service under";
              };

              environmentFile = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
                default = null;
                description = "Path to environment file for secrets";
              };

              environment = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = {};
                description = "Static environment variables";
              };

              restartSec = lib.mkOption {
                type = lib.types.str;
                default = "15s";
                description = "Systemd RestartSec duration";
              };
            };
          }
        );
        default = {};
        description = "Arbitrary custom background scripts managed at service level";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services = lib.mkMerge [
        # Photo Gallery Service
        (lib.mkIf cfg.photoGallery.enable {
          photo-gallery = {
            description = "Photo Gallery - Life Museum 24/7 Random Capture & Immich Sync";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target" "immich.service"];
            wants = ["network-online.target"];

            path = with pkgs; [
              bash
              coreutils
              curl
              jq
              ffmpeg-headless
              v4l-utils
              util-linux
            ];

            environment =
              {
                IMMICH_INSTANCE_URL = cfg.photoGallery.immichUrl;
                IMMICH_ALBUM_NAME = cfg.photoGallery.albumName;
                CAMERA_TYPE = cfg.photoGallery.cameraType;
                CAMERA_DEVICE = cfg.photoGallery.cameraDevice;
                CAMERA_RESOLUTION = cfg.photoGallery.cameraResolution;
                CAMERA_WARMUP_SECONDS = toString cfg.photoGallery.cameraWarmupSeconds;
                SCHEDULE_MODE = cfg.photoGallery.scheduleMode;
                WINDOW_START_HOUR = toString cfg.photoGallery.windowStartHour;
                WINDOW_END_HOUR = toString cfg.photoGallery.windowEndHour;
                STORAGE_DIR = "${cfg.photoGallery.dataDir}/captures";
                STATE_FILE = "${cfg.photoGallery.dataDir}/.last_capture_state";
              }
              // lib.optionalAttrs (cfg.photoGallery.cameraStreamUrl != null) {
                CAMERA_STREAM_URL = cfg.photoGallery.cameraStreamUrl;
              };

            serviceConfig =
              {
                Type = "simple";
                User = cfg.photoGallery.user;
                Group = "users";
                SupplementaryGroups = ["video"];
                WorkingDirectory = cfg.photoGallery.dataDir;
                StateDirectory = "photo-gallery";
                ExecStart = "${photoGalleryScript}/bin/photo-gallery --daemon";
                Restart = "always";
                RestartSec = "15s";
                NoNewPrivileges = true;
              }
              // lib.optionalAttrs (cfg.photoGallery.environmentFile != null) {
                EnvironmentFile = cfg.photoGallery.environmentFile;
              };
          };
        })

        # Generic Custom Shell Services
        (lib.mapAttrs' (
            name: svc:
              lib.nameValuePair "shell-repo-${name}" (lib.mkIf svc.enable {
                description = "Shell-Repo custom service: ${name}";
                wantedBy = ["multi-user.target"];
                after = ["network-online.target"];
                wants = ["network-online.target"];

                path = [pkgs.bash pkgs.coreutils] ++ svc.packages;
                inherit (svc) environment;

                serviceConfig =
                  {
                    Type = "simple";
                    User = svc.user;
                    ExecStart = lib.concatStringsSep " " (["${svc.script}"] ++ svc.args);
                    Restart = "always";
                    RestartSec = svc.restartSec;
                  }
                  // lib.optionalAttrs (svc.environmentFile != null) {
                    EnvironmentFile = svc.environmentFile;
                  };
              })
          )
          cfg.customServices)
      ];
    };
  };
}
