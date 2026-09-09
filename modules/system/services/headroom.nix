{
  flake.nixosModules.services-headroom = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.headroom;
  in {
    options.homelab.headroom = {
      enable = lib.mkEnableOption "Headroom AI context compression proxy";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8787;
        description = "Port on which Headroom proxy listens";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/headroomlabs-ai/headroom@sha256:35b799e94eef4644cb15a2e695b4b99698fe7668614623e9338cb10c10ececf9";
        description = "Docker image for Headroom";
      };

      dataDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/headroom";
        description = "Host directory for Headroom persistent state";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open port in firewall";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file containing secrets (e.g. HEADROOM_PROXY_TOKEN)";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional environment variables for Headroom container";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != null) [
        "d ${toString cfg.dataDir} 0750 root root -"
      ];

      virtualisation.oci-containers = {
        backend = lib.mkDefault "docker";
        containers.headroom = {
          inherit (cfg) image;
          autoStart = true;
          ports = [
            "127.0.0.1:${toString cfg.port}:8787"
          ];
          volumes = lib.optional (cfg.dataDir != null) "${toString cfg.dataDir}:/data";
          environment =
            {
              HEADROOM_ROLLOUT_CHANNEL = "stable";
            }
            // cfg.extraEnvironment;
          environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
    };
  };
}
