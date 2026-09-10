{
  flake.nixosModules.services-glance = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.glance;
    publicUrl = backend: let
      port = lib.findFirst (port: config.homelab.tailscaleServe.routes.${port} == backend) null (builtins.attrNames config.homelab.tailscaleServe.routes);
    in
      if port == null
      then "http://127.0.0.1:${toString backend}"
      else "https://\${HOMELAB_HOST}:${port}";
    bookmarkGroups =
      map (group: {
        inherit (group) title;
        links =
          map (
            link:
              {
                inherit (link) title;
                url = "${publicUrl link.backendPort}${link.path}";
              }
              // lib.optionalAttrs (link.icon != null) {inherit (link) icon;}
          )
          group.links;
      })
      (lib.filter (group: group.links != []) cfg.bookmarks);
    monitorSites =
      map (
        service:
          {
            inherit (service) title;
            url = "${publicUrl service.backendPort}${service.path}";
            check-url = service.checkUrl;
          }
          // lib.optionalAttrs (service.icon != null) {inherit (service) icon;}
      )
      cfg.monitoredServices;
  in {
    options.homelab.glance = {
      enable = lib.mkEnableOption "Glance homelab dashboard";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port on which Glance runs";
      };
      bookmarks = lib.mkOption {
        default = [];
        type = lib.types.listOf (lib.types.submodule {
          options = {
            title = lib.mkOption {type = lib.types.str;};
            links = lib.mkOption {
              default = [];
              type = lib.types.listOf (lib.types.submodule {
                options = {
                  title = lib.mkOption {type = lib.types.str;};
                  icon = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Optional Glance icon shown beside the bookmark";
                  };
                  backendPort = lib.mkOption {type = lib.types.port;};
                  path = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                  };
                };
              });
            };
          };
        });
        description = "Declarative Glance bookmark groups";
      };
      monitoredServices = lib.mkOption {
        default = [];
        type = lib.types.listOf (lib.types.submodule {
          options = {
            title = lib.mkOption {type = lib.types.str;};
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional Glance icon shown beside the monitored service";
            };
            backendPort = lib.mkOption {type = lib.types.port;};
            path = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Path opened when the service is selected";
            };
            checkUrl = lib.mkOption {
              type = lib.types.str;
              description = "Loopback URL used by Glance for the availability check";
            };
          };
        });
        description = "Services displayed by Glance's native monitor widget";
      };
    };

    config = lib.mkIf cfg.enable {
      services.glance = {
        enable = true;
        settings = {
          server = {
            inherit (cfg) port;
            host = "127.0.0.1";
            assets-path = ../../../assets/glance;
          };
          theme = {
            # Preserve Glance's default dark palette while lowering only the
            # background lightness (the upstream default is "240 8 9").
            background-color = "240 8 5";
            custom-css-file = "/assets/user.css";
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
                      timezones = [{timezone = "Asia/Jakarta";}];
                    }
                    {
                      type = "weather";
                      location = "Surabaya, Indonesia";
                      units = "metric";
                      hour-format = "24h";
                    }
                    {
                      type = "server-stats";
                      mountpoints = ["/"];
                    }
                  ];
                }
                {
                  size = "full";
                  widgets =
                    [
                      {
                        type = "bookmarks";
                        groups = bookmarkGroups;
                      }
                    ]
                    ++ lib.optional (cfg.monitoredServices != []) {
                      type = "monitor";
                      cache = "1m";
                      title = "Services";
                      sites = monitorSites;
                    };
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
                      repositories = ["immich-app/immich" "dani-garcia/vaultwarden" "n8n-io/n8n" "decolua/9router"];
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
