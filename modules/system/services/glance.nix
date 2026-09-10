{
  flake.nixosModules.services-glance = {
    config,
    lib,
    pkgs,
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
          map (link: {
            inherit (link) title;
            url = "${publicUrl link.backendPort}${link.path}";
          })
          group.links;
      })
      cfg.bookmarks;
    dashboardUrl = publicUrl cfg.dashboardDataPort;
    monitoredServicesJson = builtins.toJSON cfg.monitoredServices;
    photoDirectory =
      if cfg.photoSource == null
      then ""
      else cfg.photoSource.directory;
    photoImmichUrl =
      if cfg.photoSource == null
      then ""
      else publicUrl cfg.photoSource.immichBackendPort;
    nineRouterUrl =
      if cfg.nineRouterUrl == null
      then ""
      else cfg.nineRouterUrl;
    dashboardRefresh = pkgs.writeShellScript "glance-dashboard-refresh" ''
      set -eu
      output_dir=/var/lib/glance-dashboard
      mkdir -p "$output_dir"
      umask 022
      escape_html() { ${pkgs.gnused}/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
      service_rows=""
      while IFS= read -r encoded; do
        service=$(printf '%s' "$encoded" | ${pkgs.coreutils}/bin/base64 -d)
        title=$(printf '%s' "$service" | ${pkgs.jq}/bin/jq -r '.title')
        url=$(printf '%s' "$service" | ${pkgs.jq}/bin/jq -r '.url')
        if ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 5 --output /dev/null "$url"; then state=healthy; label=healthy; else state=unavailable; label=unavailable; fi
        escaped_title=$(printf '%s' "$title" | escape_html)
        service_rows="$service_rows<li><span class=\"dot $state\"></span>$escaped_title <small>$label</small></li>"
      done <<EOF
      $(printf '%s' '${monitoredServicesJson}' | ${pkgs.jq}/bin/jq -r '.[] | @base64')
      EOF
      [ -n "$service_rows" ] || service_rows='<li><small>No services configured.</small></li>'
      photo_card='<p class="empty">No photo source configured.</p>'
      latest_photo=""
      if [ -n '${photoDirectory}' ] && [ -d '${photoDirectory}' ]; then latest_photo=$(${pkgs.findutils}/bin/find '${photoDirectory}' -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -printf '%T@ %p\n' 2>/dev/null | ${pkgs.coreutils}/bin/sort -nr | ${pkgs.coreutils}/bin/head -n1 || true); fi
      if [ -n "$latest_photo" ]; then
        photo_path=''${latest_photo#* }; photo_epoch=''${latest_photo%% *}
        ${pkgs.coreutils}/bin/cp --reflink=auto "$photo_path" "$output_dir/latest.jpg"
        captured=$(${pkgs.coreutils}/bin/date -d "@$''${photo_epoch%.*}" '+%Y-%m-%d %H:%M %Z')
        photo_card="<img src=\"latest.jpg\" alt=\"Latest Photo Gallery capture\"><p>Captured $captured</p>"
        if [ -n '${photoImmichUrl}' ]; then photo_card="$photo_card<p><a href=\"${photoImmichUrl}\" target=\"_blank\" rel=\"noreferrer\">Open in Immich</a></p>"; fi
      elif [ -n '${photoDirectory}' ]; then photo_card='<p class="empty">No Photo Gallery capture is available yet.</p>'; fi
      quota_card='<p class="empty">9Router dashboard key is not configured.</p>'
      if [ -n "''${NINE_ROUTER_DASHBOARD_API_KEY:-}" ] && [ -n '${nineRouterUrl}' ]; then
        quota_file=$(mktemp); usage_file=$(mktemp); trap 'rm -f "$quota_file" "$usage_file"' EXIT
        if ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 8 -H "Authorization: Bearer $NINE_ROUTER_DASHBOARD_API_KEY" '${nineRouterUrl}/api/quota' > "$quota_file" && ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 8 -H "Authorization: Bearer $NINE_ROUTER_DASHBOARD_API_KEY" '${nineRouterUrl}/api/usage?period=today' > "$usage_file"; then
          providers=$(${pkgs.jq}/bin/jq -r '.providers[]? | "<li><strong>\(.name // .id)</strong>: \(.quota.used // "?") / \(.quota.limit // "?") \(.quota.unit // "") (\(.quota.percentage // "?")%)<br><small>Reset: \(.reset.nextReset // .reset.time // "unknown")</small></li>"' "$quota_file")
          [ -n "$providers" ] || providers='<li><small>No quota providers reported.</small></li>'
          summary=$(${pkgs.jq}/bin/jq -r '.summary // {} | "\(.requests // 0) requests · \(.tokens // 0) tokens · $\(.cost // 0) today"' "$usage_file")
          quota_card="<p>$summary</p><ul>$providers</ul>"
        else quota_card='<p class="empty">9Router usage data is currently unavailable.</p>'; fi
      fi
      tmp=$(mktemp "$output_dir/index.html.XXXXXX")
      cat > "$tmp" <<EOF
      <!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="60"><style>:root{color-scheme:dark}body{margin:0;background:#111;color:#ddd;font:14px system-ui,sans-serif}.grid{display:grid;gap:12px;grid-template-columns:repeat(2,minmax(0,1fr))}.card{background:#1b1b1b;border:1px solid #303030;border-radius:8px;padding:12px}h2{font-size:14px;margin:0 0 8px;color:#fff}p{margin:6px 0}ul{margin:6px 0;padding-left:18px}.dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px}.healthy{background:#5ac878}.unavailable{background:#d96868}small,.empty{color:#aaa}details summary{cursor:pointer;color:#fff}details ul{list-style:none;padding:0}img{display:block;width:100%;max-height:230px;object-fit:cover;border-radius:5px}a{color:#8ab4f8}@media(max-width:520px){.grid{grid-template-columns:1fr}}</style></head><body><div class="grid"><section class="card"><details><summary>Services</summary><ul>$service_rows</ul></details></section><section class="card"><h2>9Router overview</h2>$quota_card</section><section class="card"><h2>Latest Photo Gallery capture</h2>$photo_card</section></div></body></html>
      EOF
      chmod 0644 "$tmp"; mv "$tmp" "$output_dir/index.html"
    '';
  in {
    options.homelab.glance = {
      enable = lib.mkEnableOption "Glance homelab feeds and services dashboard";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port on which Glance dashboard runs";
      };
      dashboardDataPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Loopback port for the optional refreshed dashboard-data endpoint";
      };
      dashboardEnvironmentFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Root-only file containing NINE_ROUTER_DASHBOARD_API_KEY";
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
        description = "Declarative Glance bookmark groups; empty groups remain as placeholders";
      };
      monitoredServices = lib.mkOption {
        default = [];
        type = lib.types.listOf (lib.types.submodule {
          options = {
            title = lib.mkOption {type = lib.types.str;};
            url = lib.mkOption {type = lib.types.str;};
          };
        });
        description = "Local service URLs checked by the dashboard-data refresh job";
      };
      photoSource = lib.mkOption {
        default = null;
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            directory = lib.mkOption {type = lib.types.str;};
            immichBackendPort = lib.mkOption {
              type = lib.types.port;
              default = 2283;
            };
          };
        });
        description = "Optional local Photo Gallery capture directory and Immich backend port";
      };
      nineRouterUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional loopback 9Router URL queried with the dedicated dashboard key";
      };
    };
    config = lib.mkIf cfg.enable {
      assertions = lib.optional (cfg.dashboardDataPort != null) {
        assertion = config.homelab.tailscaleServe.enable && lib.any (port: config.homelab.tailscaleServe.routes.${port} == cfg.dashboardDataPort) (builtins.attrNames config.homelab.tailscaleServe.routes);
        message = "homelab.glance.dashboardDataPort must be exposed through homelab.tailscaleServe.routes.";
      };
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
                  widgets =
                    [
                      {
                        type = "clock";
                        hour-format = "24h";
                        timezones = [{timezone = "Asia/Jakarta";}];
                      }
                      {
                        type = "bookmarks";
                        groups = bookmarkGroups;
                      }
                    ]
                    ++ lib.optional (cfg.dashboardDataPort != null) {
                      type = "custom";
                      title = "Homelab overview";
                      html = ''<iframe title="Homelab overview" src="${dashboardUrl}" style="border:0;width:100%;min-height:440px"></iframe>'';
                    }
                    ++ [
                      {
                        type = "server-stats";
                        mountpoints = ["/"];
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
      systemd.services.glance-dashboard-refresh = lib.mkIf (cfg.dashboardDataPort != null) {
        description = "Refresh Glance dashboard service, photo, and 9Router data";
        after = ["network-online.target" "homelab-secrets.service"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "glance-dashboard";
          UMask = "0077";
          EnvironmentFile = lib.optional (cfg.dashboardEnvironmentFile != null) cfg.dashboardEnvironmentFile;
        };
        script = "${dashboardRefresh}";
      };
      systemd.timers.glance-dashboard-refresh = lib.mkIf (cfg.dashboardDataPort != null) {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "1min";
          RandomizedDelaySec = "15s";
        };
      };
      systemd.services.glance-dashboard-data = lib.mkIf (cfg.dashboardDataPort != null) {
        description = "Loopback-only Glance dashboard-data endpoint";
        wantedBy = ["multi-user.target"];
        after = ["glance-dashboard-refresh.service"];
        requires = ["glance-dashboard-refresh.service"];
        serviceConfig = {
          WorkingDirectory = "/var/lib/glance-dashboard";
          ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.dashboardDataPort} --bind 127.0.0.1";
          Restart = "on-failure";
          DynamicUser = true;
          StateDirectory = "glance-dashboard";
        };
      };
    };
  };
}
