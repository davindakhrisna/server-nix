{
  flake.nixosModules.services = {self, ...}: {
    imports = with self.nixosModules; [
      services-ssh
      services-immich
      services-glance
      services-vaultwarden
      services-obsidian-sync
      services-nas
      services-shell-repo
    ];
  };
}
