{
  flake.nixosModules.services-glance = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.glance;
  in {
    options.homelab.glance = {
      enable = lib.mkEnableOption "Glance homelab feeds and services dashboard";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port on which Glance dashboard runs";
      };
    };

    config = lib.mkIf cfg.enable {
      services.glance = {
        enable = true;
        settings = {
          server = {
            inherit (cfg) port;
            host = "0.0.0.0";
          };
          theme = {
            background-color = "0 0 0";
            contrast-multiplier = 1.1;
          };
          pages = [
            {
              name = "Home";
              columns = [
                {
                  size = "small";
                  widgets = [
                    {
                      type = "clock";
                      hour-format = "24h";
                      timezones = ["Asia/Jakarta"];
                    }
                    {
                      type = "bookmarks";
                      groups = [
                        {
                          title = "Homelab Services";
                          links = [
                            {
                              title = "Immich Photos";
                              url = "http://localhost:2283";
                            }
                            {
                              title = "Vaultwarden";
                              url = "http://localhost:8222";
                            }
                            {
                              title = "Obsidian CouchDB";
                              url = "http://localhost:5984/_utils";
                            }
                          ];
                        }
                        {
                          title = "AI & Automation";
                          links = [
                            {
                              title = "n8n Workflows";
                              url = "http://localhost:5678";
                            }
                            {
                              title = "OpenHands";
                              url = "http://localhost:3000";
                            }
                            {
                              title = "9Router";
                              url = "http://localhost:20128";
                            }
                            {
                              title = "Headroom";
                              url = "http://localhost:8787";
                            }
                          ];
                        }
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        };
      };

      networking.firewall.allowedTCPPorts = [cfg.port];
    };
  };
}
