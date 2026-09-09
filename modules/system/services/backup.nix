{
  flake.nixosModules.services-backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.homelab.backup;
    snapshots = "/var/lib/homelab-backup/snapshots";
    helper = pkgs.writeShellScript "homelab-backup-snapshot" (builtins.readFile ../../../scripts/backup-snapshot.sh);
    serviceUnits = lib.filter (name: builtins.hasAttr name config.systemd.services) [
      "photo-gallery"
      "immich-server"
      "immich-machine-learning"
      "n8n"
      "couchdb"
      "vaultwarden"
      "docker-nine-router"
      "docker-headroom"
      "samba-smbd"
      "postgresql"
    ];
  in {
    options.homelab.backup = {
      enable = lib.mkEnableOption "encrypted daily backups of consistent Btrfs snapshots";
      repository = lib.mkOption {
        type = lib.types.str;
        description = "Restic destination (local directory, sftp: URL or s3: URL).";
      };
      passwordFile = lib.mkOption {
        type = lib.types.str;
        default = "/persist/secrets/restic-password";
        description = "Keep an independent copy of this key to recover after disk loss.";
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional backend credentials for S3 or other remote storage.";
      };
      requiredMount = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "For external drives: refuse backups unless this path is mounted.";
      };
    };
    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = lib.all (path: config.fileSystems.${path}.fsType == "btrfs") ["/" "/persist" "/home"];
          message = "Homelab snapshot backups require Btrfs subvolumes at /, /persist and /home.";
        }
      ];
      systemd.tmpfiles.rules = ["d /var/lib/homelab-backup 0700 root root -"];
      services.restic.backups.homelab = {
        inherit (cfg) repository passwordFile environmentFile;
        initialize = true;
        # Explicit paths avoid backing up the backup repository itself.
        dynamicFilesFrom = ''
          for path in ${snapshots}/root/var/lib/* ${snapshots}/root/srv ${snapshots}/root/etc/ssh ${snapshots}/persist/secrets ${snapshots}/home; do
            case "$path" in
              */var/lib/homelab-backup|*/var/lib/docker|*/var/lib/containers|*/var/lib/systemd) continue ;;
            esac
            test ! -e "$path" || printf '%s\n' "$path"
          done
        '';
        exclude = ["**/.cache" "**/node_modules" "**/.local/share/Trash"];
        timerConfig = {
          OnCalendar = "*-*-* 03:00:00";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
        pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6"];
        runCheck = true;
        backupPrepareCommand = "${helper} prepare";
        backupCleanupCommand = "${helper} cleanup";
      };
      systemd.services.restic-backups-homelab = {
        requires = ["homelab-secrets.service"];
        after = ["homelab-secrets.service"];
        path = [pkgs.btrfs-progs pkgs.coreutils pkgs.systemd];
        environment = {
          SNAPSHOT_DIR = snapshots;
          BACKUP_UNITS = lib.concatMapStringsSep "\n" (name: "${name}.service") serviceUnits;
        };
        unitConfig.RequiresMountsFor = lib.optional (cfg.requiredMount != null) cfg.requiredMount;
        serviceConfig =
          {
            Nice = 15;
            IOSchedulingClass = "idle";
            TimeoutStartSec = "6h";
            UMask = "0077";
          }
          // lib.optionalAttrs (cfg.requiredMount != null) {
            ExecStartPre = "${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg cfg.requiredMount}";
          };
      };
    };
  };
}
