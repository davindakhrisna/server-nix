{
  flake.nixosModules.services-secrets = {
    config,
    lib,
    pkgs,
    ...
  }: {
    systemd.services =
      {
        homelab-secrets = {
          description = "Provision missing homelab credentials without replacing existing keys";
          wantedBy = ["multi-user.target"];
          before = ["n8n.service" "couchdb.service" "docker-nine-router.service" "docker-headroom.service" "photo-gallery.service" "restic-backups-homelab.service"];
          path = [pkgs.coreutils];
          script = builtins.readFile ../../../scripts/provision-secrets.sh;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
          };
        };
      }
      // lib.genAttrs (
        lib.optional config.homelab.n8n.enable "n8n"
        ++ lib.optional config.homelab.obsidianSync.enable "couchdb"
        ++ lib.optional config.homelab.nineRouter.enable "docker-nine-router"
        ++ lib.optional config.homelab.headroom.enable "docker-headroom"
        ++ lib.optional (config.homelab.shellRepo.enable && config.homelab.shellRepo.photoGallery.enable) "photo-gallery"
      ) (_: {
        requires = ["homelab-secrets.service"];
        after = ["homelab-secrets.service"];
      });
  };
}
