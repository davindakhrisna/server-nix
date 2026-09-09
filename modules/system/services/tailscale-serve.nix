{
  flake.nixosModules.services-tailscale-serve = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.tailscaleServe;
  in {
    options.homelab.tailscaleServe = {
      enable = lib.mkEnableOption "Tailscale Serve HTTPS reverse proxy with declarative routes";

      routes = lib.mkOption {
        type = lib.types.attrsOf lib.types.port;
        default = {};
        example = {"/glance" = 8080;};
        description = ''
          Path prefix to local port mappings exposed via tailscale serve.
          Requires MagicDNS and HTTPS Certificates enabled for the tailnet.
          Each route is reachable at https://<host>.<tailnet>.ts.net<path>.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.tailscale-serve = {
        description = "Tailscale Serve - declarative HTTPS routes";
        after = ["tailscaled.service" "network-online.target"];
        wants = ["tailscaled.service" "network-online.target"];
        wantedBy = ["multi-user.target"];

        path = [config.services.tailscale.package];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        # Reset first so removed routes disappear; re-apply everything declaratively.
        script =
          ''
            tailscale serve --https=443 reset || true
          ''
          + lib.concatStringsSep "\n" (lib.mapAttrsToList (
              path: port:
                "tailscale serve --bg --https=443 ${path} http://127.0.0.1:${toString port}"
            )
            cfg.routes)
          + "\ntailscale serve status";
      };
    };
  };
}
