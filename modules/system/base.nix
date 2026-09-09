{
  flake.nixosModules.base = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: {
    options.var = {
      flakePath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nixos";
        description = "Path to the NixOS configuration flake directory";
      };

      dualBoot = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Windows dual-boot support (Limine boot entry, RTC sync, NTFS driver)";
        };
        windowsEntry = lib.mkOption {
          type = lib.types.str;
          default = "boot():/EFI/Microsoft/Boot/bootmgfw.efi";
          description = "Path or UUID to Windows EFI bootloader binary in Limine format";
        };
      };
    };

    config = {
      # Boot & Kernel Hardening
      boot = {
        kernel.sysctl = {
          "kernel.kptr_restrict" = 2;
          "kernel.dmesg_restrict" = 1;
          "kernel.perf_event_paranoid" = 3;
          "kernel.yama.ptrace_scope" = 2;

          "net.ipv4.tcp_syncookies" = 1;
          "net.ipv4.conf.all.rp_filter" = 1;
          "net.ipv4.conf.default.rp_filter" = 1;
          "net.ipv4.conf.all.accept_redirects" = 0;
          "net.ipv6.conf.all.accept_redirects" = 0;
          "net.ipv4.conf.all.send_redirects" = 0;
          "net.ipv6.conf.all.accept_ra" = 1;

          "fs.protected_hardlinks" = 1;
          "fs.protected_symlinks" = 1;
          "fs.suid_dumpable" = 0;
        };

        supportedFilesystems = lib.mkIf config.var.dualBoot.enable [
          "ntfs"
        ];

        loader = {
          limine = {
            enable = true;
            efiSupport = true;
            # Install to \EFI\BOOT\BOOTX64.EFI instead of managing NVRAM boot
            # entries - some laptop firmware rejects efibootmgr entry re-creation
            # (exit status 8) during bootloader activation.
            efiInstallAsRemovable = true;
            extraEntries = lib.optionalString config.var.dualBoot.enable ''
              /Windows 10
                  protocol: efi
                  path: ${config.var.dualBoot.windowsEntry}
            '';
          };
          efi.canTouchEfiVariables = true;
        };
      };

      # Hardware clock in local time for Windows dual-boot sync
      time.hardwareClockInLocalTime = lib.mkIf config.var.dualBoot.enable true;

      # Laptop Server Power & Lid Management (Prevent sleep on lid close)
      services.logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };

      systemd.targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };

      # Shell, Git & System Helper
      programs = {
        nh = {
          enable = true;
          flake = config.var.flakePath;
        };
        # Run prebuilt dynamically-linked binaries (downloaded CLIs, fnm node, etc.)
        nix-ld.enable = true;
        zsh.enable = true;
        git = {
          enable = true;
          config = {
            safe.directory = ["*"];
          };
        };
      };

      # Core System Services
      services = {
        tailscale.enable = true;
        udisks2.enable = true;
      };

      # Environment
      environment.sessionVariables = {
        ZDOTDIR = "$HOME/.config/zsh";
        CONFIG_DIR = config.var.flakePath;
        NH_FLAKE = config.var.flakePath;
      };

      # Network Setup
      networking = {
        nameservers = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        networkmanager = {
          enable = true;
          wifi.backend = "wpa_supplicant";
          insertNameservers = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        };
      };

      # Nix Settings
      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = false;
      };

      nix = {
        nixPath = ["nixpkgs=${inputs.nixpkgs}"];
        channel.enable = false;
        settings = {
          warn-dirty = false;
          download-buffer-size = 262144000; # 250 MB (250 * 1024 * 1024)
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };
        gc = {
          automatic = true;
          persistent = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };

      # Vulnix
      systemd = {
        services.vulnix = {
          description = "vulnix CVE scan";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.vulnix}/bin/vulnix --system";
            Nice = 20;
            IOSchedulingClass = "idle";
          };
        };
        timers.vulnix = {
          description = "Weekly vulnix CVE scan";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
            RandomizedDelaySec = "2h";
          };
        };
      };

      # Docker
      virtualisation.docker.enable = true;
    };
  };
}
