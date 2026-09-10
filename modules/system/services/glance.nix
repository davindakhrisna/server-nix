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
    glanceCss = pkgs.writeText "glance-dashboard.css" ''
      :root {
        --dashboard-surface: hsl(222 30% 12%);
        --dashboard-surface-raised: hsl(221 27% 15%);
        --dashboard-border: hsl(216 24% 24% / 0.72);
        --dashboard-text: hsl(214 32% 91%);
        --dashboard-muted: hsl(215 16% 63%);
        --dashboard-accent: hsl(199 89% 62%);
        --widget-gap: 1.25rem;
        --widget-content-padding: 1.35rem;
      }

      body {
        min-height: 100vh;
        background:
          radial-gradient(circle at 14% -8%, hsl(205 70% 27% / 0.22), transparent 32rem),
          radial-gradient(circle at 90% 8%, hsl(258 58% 30% / 0.14), transparent 28rem),
          hsl(222 36% 7%);
        color: var(--dashboard-text);
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        letter-spacing: -0.01em;
      }

      .page { max-width: 1480px; }
      .page-content { padding-block: clamp(1.25rem, 3vw, 3rem); }

      .widget:not(.widget-type-clock):not(.overview-widget) {
        overflow: hidden;
        border: 1px solid var(--dashboard-border);
        border-radius: 18px;
        background: linear-gradient(145deg, hsl(222 29% 13% / 0.94), hsl(222 28% 10% / 0.94));
        box-shadow: 0 18px 45px hsl(225 60% 2% / 0.22), inset 0 1px hsl(210 50% 100% / 0.035);
      }

      .widget-header {
        padding-bottom: 0.75rem;
        color: var(--dashboard-muted);
        font-size: 0.72rem;
        font-weight: 700;
        letter-spacing: 0.12em;
        text-transform: uppercase;
      }

      .widget-type-clock {
        position: relative;
        overflow: hidden;
        min-height: 176px;
        padding: clamp(1.35rem, 3vw, 2rem);
        border: 1px solid hsl(205 45% 32% / 0.55);
        border-radius: 24px;
        background:
          linear-gradient(115deg, hsl(204 75% 22% / 0.92), hsl(222 45% 13% / 0.96) 58%, hsl(256 38% 17% / 0.92));
        box-shadow: 0 24px 70px hsl(215 80% 3% / 0.35), inset 0 1px hsl(200 100% 95% / 0.08);
      }

      .widget-type-clock::after {
        position: absolute;
        width: 260px;
        height: 260px;
        right: -75px;
        top: -125px;
        border-radius: 50%;
        background: hsl(197 100% 68% / 0.12);
        box-shadow: 0 0 90px hsl(197 100% 62% / 0.18);
        content: "";
        pointer-events: none;
      }

      .widget-type-clock .clock-time { font-weight: 650; letter-spacing: -0.055em; }
      .widget-type-clock .clock-date { color: hsl(205 35% 80%); }

      .launchpad-widget .widget-content { padding: 0.3rem; }
      .launchpad-widget .bookmarks-group { padding: 1rem; }
      .launchpad-widget .bookmarks-group-title {
        margin-bottom: 0.8rem;
        color: var(--dashboard-muted);
        font-size: 0.72rem;
        font-weight: 700;
        letter-spacing: 0.1em;
        text-transform: uppercase;
      }

      .launchpad-widget .bookmarks-link {
        margin: 0.28rem 0;
        padding: 0.58rem 0.7rem;
        border-radius: 10px;
        transition: background-color 140ms ease, color 140ms ease, transform 140ms ease;
      }

      .launchpad-widget .bookmarks-link:hover {
        background: hsl(204 68% 28% / 0.34);
        color: hsl(196 100% 82%);
        transform: translateX(3px);
      }

      .overview-widget { margin-top: 0.1rem; }
      .overview-widget iframe { border-radius: 20px; background: transparent; }

      .widget-type-server-stats .progress-bar { border-radius: 999px; }
      .widget-type-hacker-news a,
      .widget-type-releases a { line-height: 1.35; }

      a:focus-visible,
      summary:focus-visible {
        outline: 2px solid var(--dashboard-accent);
        outline-offset: 3px;
        border-radius: 4px;
      }

      @media (max-width: 700px) {
        :root { --widget-content-padding: 1rem; --widget-gap: 0.9rem; }
        .page-content { padding-inline: 0.85rem; }
        .widget-type-clock { min-height: 150px; border-radius: 18px; }
      }

      @media (prefers-reduced-motion: reduce) {
        .launchpad-widget .bookmarks-link { transition: none; }
      }
    '';
    glanceAssets = pkgs.runCommand "glance-dashboard-assets" {} ''
      mkdir -p "$out"
      cp ${glanceCss} "$out/dashboard.css"
    '';
    dashboardRefresh = pkgs.writeShellScript "glance-dashboard-refresh" ''
      set -eu
      output_dir=/var/lib/glance-dashboard
      mkdir -p "$output_dir"
      umask 022
      escape_html() { ${pkgs.gnused}/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
      service_rows=""; service_count=0; healthy_count=0
      while IFS= read -r encoded; do
        service=$(printf '%s' "$encoded" | ${pkgs.coreutils}/bin/base64 -d)
        title=$(printf '%s' "$service" | ${pkgs.jq}/bin/jq -r '.title')
        url=$(printf '%s' "$service" | ${pkgs.jq}/bin/jq -r '.url')
        service_count=$((service_count + 1))
        if ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 5 --output /dev/null "$url"; then state=healthy; label=Online; healthy_count=$((healthy_count + 1)); else state=unavailable; label=Offline; fi
        escaped_title=$(printf '%s' "$title" | escape_html)
        service_rows="$service_rows<li class=\"service\"><span class=\"status-dot $state\"></span><span class=\"service-name\">$escaped_title</span><span class=\"status-label $state\">$label</span></li>"
      done <<EOF
      $(printf '%s' '${monitoredServicesJson}' | ${pkgs.jq}/bin/jq -r '.[] | @base64')
      EOF
      [ -n "$service_rows" ] || service_rows='<li class="empty-state">No services configured.</li>'
      photo_card='<div class="empty-state"><span class="empty-icon">◇</span><p>No photo source configured</p></div>'
      latest_photo=""
      if [ -n '${photoDirectory}' ] && [ -d '${photoDirectory}' ]; then latest_photo=$(${pkgs.findutils}/bin/find '${photoDirectory}' -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -printf '%T@ %p\n' 2>/dev/null | ${pkgs.coreutils}/bin/sort -nr | ${pkgs.coreutils}/bin/head -n1 || true); fi
      if [ -n "$latest_photo" ]; then
        photo_path=''${latest_photo#* }; photo_epoch=''${latest_photo%% *}
        ${pkgs.coreutils}/bin/cp --reflink=auto "$photo_path" "$output_dir/latest.jpg"
        captured=$(${pkgs.coreutils}/bin/date -d "@$''${photo_epoch%.*}" '+%Y-%m-%d %H:%M %Z')
        photo_card="<img src=\"latest.jpg\" alt=\"Latest Photo Gallery capture\"><div class=\"photo-meta\"><span>Captured $captured</span>"
        if [ -n '${photoImmichUrl}' ]; then photo_card="$photo_card<a href=\"${photoImmichUrl}\" target=\"_blank\" rel=\"noreferrer\">Open Immich ↗</a>"; fi
        photo_card="$photo_card</div>"
      elif [ -n '${photoDirectory}' ]; then photo_card='<div class="empty-state"><span class="empty-icon">◇</span><p>Waiting for the first gallery capture</p></div>'; fi
      quota_card='<div class="empty-state"><span class="empty-icon">⌁</span><p>Add the dashboard API key to show usage</p></div>'
      if [ -n "''${NINE_ROUTER_DASHBOARD_API_KEY:-}" ] && [ -n '${nineRouterUrl}' ]; then
        quota_file=$(mktemp); usage_file=$(mktemp); trap 'rm -f "$quota_file" "$usage_file"' EXIT
        if ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 8 -H "Authorization: Bearer $NINE_ROUTER_DASHBOARD_API_KEY" '${nineRouterUrl}/api/quota' > "$quota_file" && ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 8 -H "Authorization: Bearer $NINE_ROUTER_DASHBOARD_API_KEY" '${nineRouterUrl}/api/usage?period=today' > "$usage_file"; then
          providers=$(${pkgs.jq}/bin/jq -r '.providers[]? | "<li><div><strong>\(.name // .id)</strong><small>Resets \(.reset.nextReset // .reset.time // "unknown")</small></div><span>\(.quota.percentage // "?")%</span></li>"' "$quota_file")
          [ -n "$providers" ] || providers='<li class="empty-state">No quota providers reported</li>'
          summary=$(${pkgs.jq}/bin/jq -r '.summary // {} | "\(.requests // 0) requests · \(.tokens // 0) tokens · $\(.cost // 0) today"' "$usage_file")
          quota_card="<p class=\"metric-summary\">$summary</p><ul class=\"provider-list\">$providers</ul>"
        else quota_card='<div class="empty-state"><span class="empty-icon">!</span><p>Usage data is temporarily unavailable</p></div>'; fi
      fi
      tmp=$(mktemp "$output_dir/index.html.XXXXXX")
      cat > "$tmp" <<EOF
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="60"><style>
      :root{color-scheme:dark;--surface:hsl(222 29% 12%);--border:hsl(216 24% 24%/.72);--text:hsl(214 32% 91%);--muted:hsl(215 16% 63%);--accent:hsl(199 89% 62%);--good:hsl(153 62% 54%);--bad:hsl(0 78% 65%)}
      *{box-sizing:border-box}body{margin:0;background:transparent;color:var(--text);font:14px/1.45 Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;letter-spacing:-.01em}.dashboard-header{display:flex;align-items:flex-end;justify-content:space-between;margin:0 0 12px;padding:0 2px}.eyebrow{margin:0 0 3px;color:var(--accent);font-size:11px;font-weight:750;letter-spacing:.12em;text-transform:uppercase}.dashboard-header h1{margin:0;font-size:20px;letter-spacing:-.035em}.summary{color:var(--muted);font-size:12px}.grid{display:grid;grid-template-columns:1.08fr .92fr;gap:14px}.card{overflow:hidden;min-height:158px;padding:18px;border:1px solid var(--border);border-radius:18px;background:linear-gradient(145deg,hsl(222 29% 13%/.96),hsl(222 28% 10%/.96));box-shadow:0 18px 45px hsl(225 60% 2%/.2),inset 0 1px hsl(210 50% 100%/.035)}.services-card{grid-row:span 2}.card-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}.card h2{margin:0;font-size:14px;font-weight:700}.chip{padding:4px 8px;border:1px solid hsl(153 45% 34%/.7);border-radius:999px;background:hsl(153 48% 18%/.35);color:hsl(153 65% 72%);font-size:11px;font-weight:700}.services{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0;padding:0;list-style:none}.service{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:9px;padding:10px;border:1px solid hsl(216 22% 22%/.65);border-radius:11px;background:hsl(222 24% 15%/.72)}.status-dot{width:7px;height:7px;border-radius:50%;box-shadow:0 0 12px currentColor}.status-dot.healthy{background:var(--good);color:var(--good)}.status-dot.unavailable{background:var(--bad);color:var(--bad)}.service-name{overflow:hidden;font-weight:600;text-overflow:ellipsis;white-space:nowrap}.status-label{font-size:10px;font-weight:750;text-transform:uppercase}.status-label.healthy{color:var(--good)}.status-label.unavailable{color:var(--bad)}.metric-summary{margin:0 0 10px;color:var(--muted);font-size:12px}.provider-list{display:grid;gap:7px;margin:0;padding:0;list-style:none}.provider-list li{display:flex;align-items:center;justify-content:space-between;padding:8px 10px;border-radius:10px;background:hsl(222 24% 15%/.72)}.provider-list strong,.provider-list small{display:block}.provider-list small{margin-top:2px;color:var(--muted);font-size:10px}.provider-list>li>span{color:var(--accent);font-weight:750}img{display:block;width:100%;height:108px;object-fit:cover;border-radius:11px}.photo-meta{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-top:10px;color:var(--muted);font-size:11px}.photo-meta a{color:var(--accent);text-decoration:none}.empty-state{display:flex;min-height:84px;flex-direction:column;align-items:center;justify-content:center;color:var(--muted);text-align:center}.empty-state p{margin:6px 0 0}.empty-icon{display:grid;width:28px;height:28px;place-items:center;border:1px solid var(--border);border-radius:9px;color:var(--accent);font-weight:800}@media(max-width:620px){.grid{grid-template-columns:1fr}.services-card{grid-row:auto}.services{grid-template-columns:1fr}.summary{display:none}.card{border-radius:15px;padding:15px}}
      </style></head><body><header class="dashboard-header"><div><p class="eyebrow">System pulse</p><h1>Homelab overview</h1></div><span class="summary">$healthy_count of $service_count services online</span></header><main class="grid"><section class="card services-card"><div class="card-header"><h2>Services</h2><span class="chip">Live</span></div><ul class="services">$service_rows</ul></section><section class="card"><div class="card-header"><h2>9Router usage</h2></div>$quota_card</section><section class="card"><div class="card-header"><h2>Latest capture</h2></div>$photo_card</section></main></body></html>
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
            assets-path = glanceAssets;
          };
          theme = {
            background-color = "222 36 7";
            primary-color = "199 89 62";
            positive-color = "153 62 54";
            negative-color = "0 78 65";
            contrast-multiplier = 1.08;
            text-saturation-multiplier = 0.8;
            custom-css-file = "/assets/dashboard.css";
            disable-picker = true;
          };
          branding = {
            app-name = "Homelab";
            logo-text = "H";
            hide-footer = true;
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
                        css-class = "hero-clock";
                        timezones = [{timezone = "Asia/Jakarta";}];
                      }
                      {
                        type = "bookmarks";
                        title = "Launchpad";
                        css-class = "launchpad-widget";
                        groups = bookmarkGroups;
                      }
                    ]
                    ++ lib.optional (cfg.dashboardDataPort != null) {
                      type = "iframe";
                      source = dashboardUrl;
                      height = 525;
                      frameless = true;
                      css-class = "overview-widget";
                    }
                    ++ [
                      {
                        type = "server-stats";
                        title = "Host resources";
                        css-class = "resources-widget";
                        mountpoints = ["/"];
                      }
                    ];
                }
                {
                  size = "small";
                  widgets = [
                    {
                      type = "hacker-news";
                      title = "Tech pulse";
                      css-class = "feed-widget";
                      limit = 15;
                      collapse-after = 5;
                      sort-by = "hot";
                    }
                    {
                      type = "releases";
                      title = "Release watch";
                      css-class = "releases-widget";
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
