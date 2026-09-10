config: let
  c = config;
  backendPorts = [8080 2283 8222 5678 5984 20128 8787 3000];
in
  assert !c.homelab.openhands.enable;
  assert !(builtins.hasAttr "openhands" c.virtualisation.oci-containers.containers);
  assert !(builtins.elem "docker" (c.systemd.services.glance.serviceConfig.SupplementaryGroups or []));
  assert c.services.immich.host == "127.0.0.1";
  assert c.services.couchdb.bindAddress == "127.0.0.1";
  assert c.services.vaultwarden.config.ROCKET_ADDRESS == "127.0.0.1";
  assert c.services.n8n.environment.N8N_LISTEN_ADDRESS == "127.0.0.1";
  assert builtins.all (port: !(builtins.elem port c.networking.firewall.allowedTCPPorts)) backendPorts;
  assert !(builtins.elem 22 c.networking.firewall.allowedTCPPorts);
  assert builtins.elem "tailscale0" c.networking.firewall.trustedInterfaces;
  assert builtins.elem "--ssh" c.services.tailscale.extraUpFlags;
  assert c.homelab.ssh.tailscaleSshUsers == ["arpeggio.gns@gmail.com"];
  assert c.homelab.ssh.tailscaleSshTargetUser == "kryisnn";
  assert c.services.glance.settings.theme.custom-css-file == "/assets/dashboard.css";
  assert c.services.glance.settings.theme.disable-picker;
  assert c.services.glance.settings.branding.app-name == "Homelab";
  assert builtins.hasAttr "assets-path" c.services.glance.settings.server;
  assert builtins.length (builtins.elemAt c.services.glance.settings.pages 0).columns == 2;
  assert builtins.all (
    container:
      builtins.match ".+@sha256:[0-9a-f]{64}" container.image
      != null
      && builtins.all (port: builtins.match "127.0.0.1:.*" port != null) container.ports
  ) (builtins.attrValues c.virtualisation.oci-containers.containers);
  assert c.services.samba.settings.nas."guest ok" == "no";
  assert c.services.samba.settings.nas."path" == "/srv/nas";
  assert c.homelab.tailscaleServe.routes."8443" == 2283;
  assert c.homelab.tailscaleServe.routes."8449" == 8081;
  assert builtins.match ".*--bind 127\\.0\\.0\\.1.*" c.systemd.services.glance-dashboard-data.serviceConfig.ExecStart != null;
  assert c.homelab.glance.monitoredServices != [];
  assert c.homelab.glance.photoSource.directory == "/var/lib/photo-gallery/captures";
  assert !(builtins.any (value: builtins.isString value && builtins.match ".*NINE_ROUTER_DASHBOARD_API_KEY.*" value != null) (builtins.attrValues c.services.glance.settings));
  assert c.services.restic.backups.homelab.initialize;
  assert c.services.restic.backups.homelab.runCheck;
  assert !c.services.immich.machine-learning.enable;
  assert c.homelab.shellRepo.autoVc.enable;
  assert c.homelab.shellRepo.autoVc.intervalSeconds == 60; true
