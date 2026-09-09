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
        description = "Admin user for CouchDB initialization";
      };

      adminPasswordFile = lib.mkOption {
        type = lib.types.path;
        default = "/persist/secrets/obsidian-sync-admin-password";
        description = ''
          File containing the CouchDB admin password (plain text, single line).
          Read at runtime so the password never lands in git or the Nix store.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      services.couchdb = {
        enable = true;
        bindAddress = "127.0.0.1";
        inherit (cfg) port adminUser;
        # Admin credentials are injected at runtime via an ini fragment under
        # /run so the password never enters the world-readable Nix store.
        extraConfigFiles = ["/run/couchdb-admin/admin.ini"];

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

      systemd.services.couchdb = {
        serviceConfig.RuntimeDirectory = "couchdb-admin";
        serviceConfig.RuntimeDirectoryMode = "0700";
        serviceConfig.LoadCredential = ["admin-password:${toString cfg.adminPasswordFile}"];
        preStart = lib.mkAfter ''
          install -m 600 /dev/null /run/couchdb-admin/admin.ini
          password=$(cat "$CREDENTIALS_DIRECTORY/admin-password")
          test -n "$password"
          printf '[admins]\n%s = %s\n' \
            ${lib.escapeShellArg cfg.adminUser} \
            "$password" \
            > /run/couchdb-admin/admin.ini
        '';
      };
    };
  };
}
