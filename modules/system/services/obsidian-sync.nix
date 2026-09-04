{
  flake.nixosModules.services-obsidian-sync = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.obsidianSync;
  in {
    options.homelab.obsidianSync = {
      enable = lib.mkEnableOption "CouchDB backend tailored for Obsidian Self-Hosted LiveSync";

      port = lib.mkOption {
        type = lib.types.port;
        default = 5984;
        description = "Port on which CouchDB runs for Obsidian LiveSync";
      };

      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Default admin user for CouchDB initialization";
      };

      adminPassword = lib.mkOption {
        type = lib.types.str;
        default = "changeme_obsidian_sync";
        description = "Admin password for CouchDB initialization (Change this!)";
      };
    };

    config = lib.mkIf cfg.enable {
      services.couchdb = {
        enable = true;
        bindAddress = "0.0.0.0";
        inherit (cfg) port adminUser;
        adminPass = cfg.adminPassword;

        # Optimized configuration for Obsidian LiveSync plugin requirements
        extraConfig = {
          couchdb = {
            single_node = true;
            max_document_size = 50000000;
          };

          chttpd = {
            require_valid_user = true;
            max_http_request_size = 4294967296;
            enable_cors = true;
          };

          chttpd_auth = {
            require_valid_user = true;
          };

          cors = {
            origins = "app://obsidian.md, capacitor://localhost, http://localhost";
            credentials = true;
            headers = "accept, authorization, content-type, origin, referer";
            methods = "GET,PUT,POST,HEAD,DELETE";
            max_age = 3600;
          };
        };
      };

      networking.firewall.allowedTCPPorts = [cfg.port];
    };
  };
}
