config: let
  c = config;
  primaryUser = c.var.primaryUser;
  backendPorts = [8080 2283 8222 5678 5984 20128 8787 3000];
  leftWidgets = (builtins.elemAt (builtins.elemAt c.services.glance.settings.pages 0).columns 0).widgets;
  weatherWidgets = builtins.filter (widget: widget.type == "weather") leftWidgets;
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
  assert builtins.elem "--ssh" c.services.tailscale.extraSetFlags;
  assert primaryUser != null;
  assert builtins.hasAttr primaryUser c.users.users;
  assert c.homelab.ssh.tailscaleSshUsers == [] || c.homelab.ssh.tailscaleSshTargetUser == primaryUser;
  assert c.services.glance.settings.theme.background-color == "240 8 5";
  assert c.services.glance.settings.theme.custom-css-file == "/assets/user.css";
  assert builtins.length (builtins.elemAt c.services.glance.settings.pages 0).columns == 3;
  assert c.homelab.glance.weatherLocation == null -> weatherWidgets == [];
  assert c.homelab.glance.weatherLocation != null -> (builtins.head weatherWidgets).location == c.homelab.glance.weatherLocation;
  assert builtins.all (
    container:
      builtins.match ".+@sha256:[0-9a-f]{64}" container.image
      != null
      && builtins.all (port: builtins.match "127.0.0.1:.*" port != null) container.ports
  ) (builtins.attrValues c.virtualisation.oci-containers.containers);
  assert c.services.samba.settings.nas."guest ok" == "no";
  assert c.services.samba.settings.nas."path" == "/srv/nas";
  assert c.homelab.tailscaleServe.routes."8443" == 2283;
  assert c.homelab.tailscaleServe.routes."8447" == c.homelab.nineRouter.port;
  assert builtins.elem "/run/homelab-urls/nine-router.env" c.virtualisation.oci-containers.containers.nine-router.environmentFiles;
  assert builtins.elem "tailscale-serve.service" c.systemd.services.docker-nine-router.requires;
  assert !(builtins.hasAttr "8449" c.homelab.tailscaleServe.routes);
  assert !(builtins.hasAttr "glance-dashboard-data" c.systemd.services);
  assert c.homelab.glance.monitoredServices != [];
  assert (builtins.elemAt (builtins.elemAt (builtins.elemAt c.services.glance.settings.pages 0).columns 1).widgets 1).type == "monitor";
  assert c.services.restic.backups.homelab.initialize;
  assert c.services.restic.backups.homelab.runCheck;
  assert !c.services.immich.machine-learning.enable;
  assert !c.homelab.shellRepo.autoVc.enable || c.homelab.shellRepo.autoVc.intervalSeconds == 60; true
