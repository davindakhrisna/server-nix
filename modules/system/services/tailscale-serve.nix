{
  flake.nixosModules.services-tailscale-serve = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.homelab.tailscaleServe;
    publicPort = backend: lib.findFirst (port: cfg.routes.${port} == backend) null (builtins.attrNames cfg.routes);
    n8nPort = publicPort config.homelab.n8n.port;
    vaultPort = publicPort config.homelab.vaultwarden.port;
    nineRouterPort = publicPort config.homelab.nineRouter.port;
  in {
    options.homelab.tailscaleServe = {
      enable = lib.mkEnableOption "Tailscale Serve HTTPS reverse proxy with declarative routes";

      routes = lib.mkOption {
        type = lib.types.attrsOf lib.types.port;
        default = {};
        example = {
          "443" = 8080;
          "8443" = 2283;
        };
        description = ''
          HTTPS listen port to loopback backend port mappings.
          Requires MagicDNS and HTTPS Certificates enabled for the tailnet.
          Each app is served at https://<host>.<tailnet>.ts.net:<port>/.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = lib.all (port:
            builtins.match "[0-9]+" port
            != null
            && lib.toInt port > 0
            && lib.toInt port <= 65535
            && !(builtins.elem (lib.toInt port) (builtins.attrValues cfg.routes))) (builtins.attrNames cfg.routes);
          message = "Tailscale HTTPS ports must be valid ports distinct from all loopback backend ports.";
        }
      ];
      systemd.services.tailscale-serve = {
        description = "Tailscale Serve - declarative HTTPS routes";
        after = ["tailscaled.service" "network-online.target"];
        wants = ["tailscaled.service" "network-online.target"];
        wantedBy = ["multi-user.target"];

        path = [config.services.tailscale.package pkgs.jq pkgs.coreutils pkgs.systemd];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "30s";
          TimeoutStartSec = "60s";
          RuntimeDirectory = "homelab-urls";
          RuntimeDirectoryPreserve = "yes";
        };

        # Reset first so removed routes disappear; re-apply everything declaratively.
        script =
          ''
            # Do not erase working routes while the node is logged out.
            dns_name=$(tailscale status --json | jq -er '.Self.DNSName | select(type == "string" and length > 0) | rtrimstr(".")')
            tailscale serve reset
          ''
          + lib.concatStringsSep "\n" (lib.mapAttrsToList (
              httpsPort: port: "tailscale serve --bg --https=${lib.escapeShellArg httpsPort} http://127.0.0.1:${toString port}"
            )
            cfg.routes)
          + ''

            # Applications need their actual public URLs for cookies and callbacks.
            update_env() {
              file="$1"
              cat > "/run/homelab-urls/$file.new"
              chmod 0644 "/run/homelab-urls/$file.new"
              if ! cmp -s "/run/homelab-urls/$file.new" "/run/homelab-urls/$file"; then
                mv "/run/homelab-urls/$file.new" "/run/homelab-urls/$file"
              else
                rm "/run/homelab-urls/$file.new"
              fi
            }
            printf 'HOMELAB_HOST=%s\n' "$dns_name" | update_env glance.env
          ''
          + lib.optionalString (n8nPort != null) ''
            printf 'WEBHOOK_URL=https://%s:${n8nPort}/\nN8N_EDITOR_BASE_URL=https://%s:${n8nPort}/\n' "$dns_name" "$dns_name" | update_env n8n.env
          ''
          + lib.optionalString (vaultPort != null) ''
            printf 'DOMAIN=https://%s:${vaultPort}\n' "$dns_name" | update_env vaultwarden.env
          ''
          + lib.optionalString (nineRouterPort != null) ''
            printf 'BASE_URL=https://%s:${nineRouterPort}\nNEXT_PUBLIC_BASE_URL=https://%s:${nineRouterPort}\nAUTH_COOKIE_SECURE=true\n' "$dns_name" "$dns_name" | update_env nine-router.env
          ''
          + ''
            # Pipeline functions run in subshells; refresh these small services
            # whenever routes are explicitly reapplied (boot/rebuild/restart).
            systemctl --no-block try-restart ${lib.concatStringsSep " " (
              lib.optional config.homelab.glance.enable "glance.service"
              ++ lib.optional config.homelab.n8n.enable "n8n.service"
              ++ lib.optional config.homelab.vaultwarden.enable "vaultwarden.service"
              ++ lib.optional config.homelab.nineRouter.enable "docker-nine-router.service"
            )}
            tailscale serve status
          '';
      };
    };
  };
}
