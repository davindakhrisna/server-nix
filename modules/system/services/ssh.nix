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
        description = "Tailnet identities documented in the separately applied Tailscale SSH policy; this option does not modify tailnet control-plane policy";
      };

      tailscaleSshTargetUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Local account documented in the separately applied Tailscale SSH policy";
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
        # Reconcile this on every activation, including for nodes that were
        # authenticated interactively before this option was configured.
        extraSetFlags = [
          "--ssh" # Enable Tailscale SSH for authenticated tailnet nodes
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
