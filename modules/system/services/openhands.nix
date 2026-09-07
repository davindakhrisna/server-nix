{
  flake.nixosModules.services-openhands = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.openhands;
  in {
    options.homelab.openhands = {
      enable = lib.mkEnableOption "OpenHands AI software development agent";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port on which OpenHands web interface listens";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.openhands.dev/openhands/openhands:latest";
        description = "Docker image for OpenHands";
      };

      workspaceDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/openhands/workspace";
        description = "Host directory mounted as the OpenHands workspace";
      };

      stateDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/openhands/state";
        description = "Host directory for storing OpenHands state and configuration";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open port in firewall";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file containing secrets (e.g. LLM API keys)";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional environment variables for OpenHands container";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d ${toString cfg.workspaceDir} 0775 root docker -"
        "d ${toString cfg.stateDir} 0775 root docker -"
      ];

      virtualisation.oci-containers = {
        backend = lib.mkDefault "docker";
        containers.openhands = {
          inherit (cfg) image;
          autoStart = true;
          ports = [
            "${toString cfg.port}:3000"
          ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock"
            "${toString cfg.workspaceDir}:/opt/workspace_base"
            "${toString cfg.stateDir}:/.openhands-state"
          ];
          environment =
            {
              WORKSPACE_BASE = toString cfg.workspaceDir;
              LOG_ALL_EVENTS = "true";
            }
            // cfg.extraEnvironment;
          environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          extraOptions = [
            "--add-host=host.docker.internal:host-gateway"
          ];
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
    };
  };
}
