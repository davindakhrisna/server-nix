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

    autoVcScript = pkgs.writeShellScriptBin "auto-vc" (
      builtins.readFile ../../../shell-repo/auto-vc/auto-vc.sh
    );

    waneScript = pkgs.writeShellScriptBin "wane" (
      builtins.readFile ../../../shell-repo/wane-watcher/wane.sh
    );

    # Primary user = the normal (human) user with the lowest uid, i.e. the
    # first account created. Hosts with several users should set the user
    # options explicitly.
    primaryUser =
      if config.var.primaryUser != null
      then config.var.primaryUser
      else let
        users = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
        sorted = lib.sort (a: b: (users.${a}.uid or 1000) < (users.${b}.uid or 1000)) (lib.attrNames users);
      in
        lib.head sorted;

    photoGalleryUser =
      if cfg.photoGallery.user != null
      then cfg.photoGallery.user
      else primaryUser;

    autoVcUser =
      if cfg.autoVc.user != null
      then cfg.autoVc.user
      else primaryUser;

    autoVcSshKey =
      if cfg.autoVc.sshKeyPath != null
      then cfg.autoVc.sshKeyPath
      else "/home/${autoVcUser}/.ssh/id_github_deploy";
  in {
    options.homelab.shellRepo = {
      enable = lib.mkEnableOption "Shell-Repo service runner for custom background scripts";

      photoGallery = {
        enable = lib.mkEnableOption "automated camera capture and Immich sync daemon";

        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "User to run the photo-gallery daemon as (default: first normal user account)";
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
          default = "Automated Captures";
          description = "Target Immich album name for daily captures";
        };

        albumDescription = lib.mkOption {
          type = lib.types.str;
          default = "Automated camera captures";
          description = "Description assigned when creating the Immich album";
        };

        deviceId = lib.mkOption {
          type = lib.types.str;
          default = "server-camera";
          description = "Device identifier reported to Immich for uploaded captures";
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

      autoVc = {
        enable = lib.mkEnableOption "Auto-VC automated Git add, commit, and push 24/7 daemon";

        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "User to run the auto-vc daemon as (default: first normal user account)";
        };

        repoPath = lib.mkOption {
          type = lib.types.str;
          default = config.var.flakePath;
          description = "Path to the git repository to track and sync";
        };

        branch = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "Target Git branch to push changes to";
        };

        remote = lib.mkOption {
          type = lib.types.str;
          default = "origin";
          description = "Git remote name";
        };

        intervalSeconds = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Interval in seconds between git checks";
        };

        sshKeyPath = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
          default = null;
          description = ''
            Path to SSH private key used for git push.
            Default (null): /home/<primary-user>/.ssh/id_github_deploy
          '';
        };

        commitPrefix = lib.mkOption {
          type = lib.types.str;
          default = "chore(auto-vc)";
          description = "Prefix for automated commit messages";
        };

        pullBeforePush = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Pull remote changes with rebase before pushing";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
          default = null;
          description = "Path to environment file for extra secrets or environment variables";
        };
      };

      waneWatcher = {
        enable = lib.mkEnableOption "WANE (Warnings And Errors) 24/7 system journal watcher and log inspector";

        logFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/log/wane/wane-log";
          description = "Path to central wane-log file";
        };

        maxLogSizeMB = lib.mkOption {
          type = lib.types.int;
          default = 50;
          description = "Maximum size in megabytes before log rotates/truncates";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "User to run wane-watcher collector under";
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
      environment.systemPackages = lib.mkIf cfg.waneWatcher.enable [
        waneScript
      ];

      systemd.tmpfiles.rules = lib.mkIf cfg.waneWatcher.enable [
        "d /var/log/wane 0775 root users -"
        "f /var/log/wane/wane-log 0664 root users -"
      ];

      systemd.services = lib.mkMerge [
        # Photo Gallery Service
        (lib.mkIf cfg.photoGallery.enable {
          photo-gallery = {
            description = "Photo Gallery - Automated Camera Capture & Immich Sync";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target" "immich.service"];
            wants = ["network-online.target"];
            # A real Immich API key must be supplied by the account owner.
            # Missing credentials skip capture rather than causing a restart loop.

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
                IMMICH_ALBUM_DESCRIPTION = cfg.photoGallery.albumDescription;
                IMMICH_DEVICE_ID = cfg.photoGallery.deviceId;
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
                User = photoGalleryUser;
                Group = "users";
                SupplementaryGroups = ["video"];
                WorkingDirectory = cfg.photoGallery.dataDir;
                StateDirectory = "photo-gallery";
                StateDirectoryMode = "0700";
                UMask = "0077";
                ExecStart = "${photoGalleryScript}/bin/photo-gallery --daemon";
                ExecCondition = pkgs.writeShellScript "photo-gallery-ready" ''
                  test -n "''${IMMICH_API_KEY:-}"
                '';
                Restart = "always";
                RestartSec = "15s";
                NoNewPrivileges = true;
              }
              // lib.optionalAttrs (cfg.photoGallery.environmentFile != null) {
                EnvironmentFile = cfg.photoGallery.environmentFile;
              };
          };
        })

        # Auto-VC Service
        (lib.mkIf cfg.autoVc.enable {
          auto-vc = {
            description = "Auto-VC - 24/7 Automated Git Add, Commit & Push Daemon";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];

            path = with pkgs; [
              bash
              coreutils
              git
              openssh
              gnugrep
              gnused
              gawk
            ];

            environment =
              {
                REPO_PATH = cfg.autoVc.repoPath;
                GIT_BRANCH = cfg.autoVc.branch;
                GIT_REMOTE = cfg.autoVc.remote;
                CHECK_INTERVAL = toString cfg.autoVc.intervalSeconds;
                COMMIT_PREFIX = cfg.autoVc.commitPrefix;
                PULL_BEFORE_PUSH =
                  if cfg.autoVc.pullBeforePush
                  then "true"
                  else "false";
                HOME = "/home/${autoVcUser}";
              }
              // lib.optionalAttrs (autoVcSshKey != null) {
                GIT_SSH_COMMAND = "ssh -i ${autoVcSshKey} -o StrictHostKeyChecking=accept-new -o BatchMode=yes";
              };

            serviceConfig =
              {
                Type = "simple";
                User = autoVcUser;
                Group = "users";
                WorkingDirectory = cfg.autoVc.repoPath;
                ExecStart = "${autoVcScript}/bin/auto-vc --daemon";
                Restart = "always";
                RestartSec = "15s";
                NoNewPrivileges = true;
              }
              // lib.optionalAttrs (cfg.autoVc.environmentFile != null) {
                EnvironmentFile = cfg.autoVc.environmentFile;
              };
          };
        })

        # WANE Watcher Service
        (lib.mkIf cfg.waneWatcher.enable {
          wane-watcher = {
            description = "WANE - 24/7 System Warning & Error Watcher Daemon";
            wantedBy = ["multi-user.target"];
            after = ["systemd-journald.service"];
            wants = ["systemd-journald.service"];

            path = with pkgs; [
              bash
              coreutils
              systemd
              jq
              gnugrep
              gawk
              util-linux
            ];

            environment = {
              WANE_LOG_FILE = cfg.waneWatcher.logFile;
              WANE_MAX_SIZE_MB = toString cfg.waneWatcher.maxLogSizeMB;
            };

            serviceConfig = {
              Type = "simple";
              User = cfg.waneWatcher.user;
              Group = "users";
              ExecStart = "${waneScript}/bin/wane --daemon";
              Restart = "always";
              RestartSec = "10s";
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
