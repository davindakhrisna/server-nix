config: let
  c = config;
in
  assert c.var.primaryUser == "operator";
  assert c.homelab.ssh.tailscaleSshUsers == [];
  assert c.homelab.ssh.tailscaleSshTargetUser == null;
  assert c.homelab.glance.bookmarks == [];
  assert c.homelab.glance.monitoredServices == [];
  assert c.homelab.glance.weatherLocation == null; true
