{
  flake.nixosModules.services-glance = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.glance;
    publicUrl = backend: let
      port =
        lib.findFirst (port: config.homelab.tailscaleServe.routes.${port} == backend) null
        (builtins.attrNames config.homelab.tailscaleServe.routes);
    in
      if port == null
      then "http://127.0.0.1:${toString backend}"
      else "https://\${HOMELAB_HOST}:${port}";
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
            host = "127.0.0.1";
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
                  size = "full";
                  widgets = [
                    {
                      type = "clock";
                      hour-format = "24h";
                      timezones = [
                        {timezone = "Asia/Jakarta";}
                      ];
                    }
                    {
                      type = "bookmarks";
                      groups = [
                        {
                          title = "Homelab Services";
                          links = [
                            {
                              title = "Immich Photos";
                              url = publicUrl 2283;
                            }
                            {
                              title = "Vaultwarden";
                              url = publicUrl 8222;
                            }
                            {
                              title = "Obsidian CouchDB";
                              url = "${publicUrl 5984}/_utils";
                            }
                          ];
                        }
                        {
                          title = "AI & Automation";
                          links = [
                            {
                              title = "n8n Workflows";
                              url = publicUrl 5678;
                            }
                            {
                              title = "9Router";
                              url = publicUrl 20128;
                            }
                            {
                              title = "Headroom";
                              url = publicUrl 8787;
                            }
                          ];
                        }
                      ];
                    }
                    {
                      type = "monitor";
                      cache = "1m";
                      title = "Services";
                      sites = [
                        {
                          title = "Glance";
                          url = "http://127.0.0.1:8080";
                        }
                        {
                          title = "n8n";
                          url = "http://127.0.0.1:5678";
                        }
                        {
                          title = "Immich";
                          url = "http://127.0.0.1:2283";
                        }
                        {
                          title = "Vaultwarden";
                          url = "http://127.0.0.1:8222";
                        }
                        {
                          title = "Obsidian Sync";
                          url = "http://127.0.0.1:5984";
                        }
                        {
                          title = "9Router";
                          url = "http://127.0.0.1:20128";
                        }
                        {
                          title = "Headroom";
                          url = "http://127.0.0.1:8787/health";
                        }
                      ];
                    }
                    {
                      type = "server-stats";
                      mountpoints = [
                        "/"
                      ];
                    }
                  ];
                }
                {
                  size = "small";
                  widgets = [
                    {
                      type = "hacker-news";
                      limit = 15;
                      collapse-after = 5;
                      sort-by = "hot";
                    }
                    {
                      type = "releases";
                      repositories = [
                        "immich-app/immich"
                        "dani-garcia/vaultwarden"
                        "n8n-io/n8n"
                        "decolua/9router"
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        };
      };

      systemd.services.glance = {
        environment.HOMELAB_HOST = "localhost";
        serviceConfig.EnvironmentFile = lib.mkForce "-/run/homelab-urls/glance.env";
      };
    };
  };
}
