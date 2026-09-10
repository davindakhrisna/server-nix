{
  flake.nixosModules.services-ssh = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.ssh;
  in {
    options.homelab.ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable hardened OpenSSH and Tailscale SSH integration";
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "SSH public keys allowed to log into normal user accounts";
      };

      tailscaleSshUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tailnet identities permitted by the accompanying Tailscale SSH policy";
      };

      tailscaleSshTargetUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Local account that the Tailscale SSH policy may target";
      };
    };

    config = lib.mkIf cfg.enable {
      # Hardened OpenSSH Server
      services.openssh = {
        enable = true;
        ports = [22];
        # The daemon remains available on tailscale0 because that interface is
        # trusted below; do not let the OpenSSH module open it globally.
        openFirewall = false;

        settings = {
          # Strictly forbid password authentication
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;

          # Security hardening
          PermitRootLogin = "no";
          X11Forwarding = false;
          MaxAuthTries = 3;
        };

        # Host key algorithms
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      # Tailscale Integration
      services.tailscale = {
        enable = true;
        useRoutingFeatures = "server";
        extraUpFlags = [
          "--ssh" # Enable Tailscale SSH (zero-password auth for authenticated tailscale nodes)
        ];
      };

      # Firewall Configuration
      networking.firewall = {
        enable = true;
        # Trust all traffic originating on the Tailscale virtual interface
        trustedInterfaces = ["tailscale0"];
      };

      assertions = [
        {
          assertion = cfg.tailscaleSshUsers == [] || cfg.tailscaleSshTargetUser != null;
          message = "homelab.ssh.tailscaleSshTargetUser must be set when tailscaleSshUsers is nonempty.";
        }
      ];

      # Automatically inject authorized keys into all normal users if specified
      users.users = lib.mkIf (cfg.authorizedKeys != []) (
        lib.mapAttrs (_: _: {
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
        }) (lib.filterAttrs (_: u: u.isNormalUser) config.users.users)
      );
    };
  };
}
