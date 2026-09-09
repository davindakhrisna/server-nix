{
  flake.nixosModules.services-n8n = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.n8n;
  in {
    options.homelab.n8n = {
      enable = lib.mkEnableOption "n8n workflow automation platform";

      port = lib.mkOption {
        type = lib.types.port;
        default = 5678;
        description = "Port on which n8n web and webhook server listens";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open port in firewall";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/n8n";
        readOnly = true;
        description = "State directory fixed by the upstream n8n module";
      };

      webhookUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Public URL for webhooks (e.g. https://n8n.yourdomain.com/ or http://homelab:5678)";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Path to environment file containing secrets (e.g. /persist/secrets/n8n.env)";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional environment variables for n8n";
      };
    };

    config = lib.mkIf cfg.enable {
      services.n8n = {
        enable = true;
        inherit (cfg) openFirewall;
        environment =
          {
            N8N_PORT = toString cfg.port;
            N8N_LISTEN_ADDRESS = "127.0.0.1";
            N8N_PROXY_HOPS = "1";
          }
          // lib.optionalAttrs (cfg.webhookUrl != null) {
            WEBHOOK_URL = cfg.webhookUrl;
          }
          // cfg.extraEnvironment;
      };

      systemd.services.n8n = lib.mkIf (cfg.environmentFile != null) {
        serviceConfig.EnvironmentFile =
          [cfg.environmentFile]
          ++ lib.optional config.homelab.tailscaleServe.enable "-/run/homelab-urls/n8n.env";
      };
    };
  };
}
