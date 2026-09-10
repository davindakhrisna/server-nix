config: let
  c = config;
in
  assert c.homelab.ssh.tailscaleSshUsers == [];
  assert c.homelab.ssh.tailscaleSshTargetUser == null;
  assert c.homelab.glance.bookmarks == [];
  assert c.homelab.glance.monitoredServices == []; true
