{
  flake.nixosModules.services-nine-router = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.nineRouter;
  in {
    options.homelab.nineRouter = {
      enable = lib.mkEnableOption "9Router open-source AI gateway and proxy router";

      port = lib.mkOption {
        type = lib.types.port;
        default = 20128;
        description = "Port on which 9router listens";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "decolua/9router@sha256:47c17576ad49f0918d1a455dd412ae4509ee8bc742f17ba0b3327ddc70f35a40";
        description = "Docker image for 9router";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/9router";
        description = "Host directory for 9router data and configuration";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open port in firewall";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file containing secrets or API tokens";
      };

      publicEnvironmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Runtime-generated environment file containing the public HTTPS origin";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional environment variables for 9router container";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        # 9router image runs as uid 1000 (node) and writes jwt-secret,
        # model catalogs, etc. into the data dir
        "d ${toString cfg.dataDir} 0750 1000 1000 -"
      ];

      virtualisation.oci-containers = {
        backend = lib.mkDefault "docker";
        containers.nine-router = {
          inherit (cfg) image;
          autoStart = true;
          ports = [
            "127.0.0.1:${toString cfg.port}:20128"
          ];
          volumes = [
            "${toString cfg.dataDir}:/app/data"
          ];
          environment =
            {
              DATA_DIR = "/app/data";
              PORT = "20128";
            }
            // cfg.extraEnvironment;
          environmentFiles =
            lib.optional (cfg.environmentFile != null) cfg.environmentFile
            ++ lib.optional (cfg.publicEnvironmentFile != null) cfg.publicEnvironmentFile;
        };
      };

      systemd.services.docker-nine-router = lib.mkIf (cfg.publicEnvironmentFile != null) {
        requires = ["tailscale-serve.service"];
        after = ["tailscale-serve.service"];
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
    };
  };
}
