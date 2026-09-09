{
  flake.nixosModules.resources = {
    config,
    lib,
    ...
  }: {
    options.homelab.lowMemory = lib.mkEnableOption "reduced background work for a small homelab";
    config = lib.mkIf config.homelab.lowMemory {
      zramSwap = {
        enable = true;
        memoryPercent = 25;
      };
      nix.settings = {
        max-jobs = lib.mkDefault 1;
        cores = lib.mkDefault 2;
      };
      services.immich.machine-learning.enable = lib.mkDefault false;
      systemd.services =
        lib.genAttrs (
          lib.optional config.homelab.immich.enable "immich-server"
          ++ lib.optional config.homelab.n8n.enable "n8n"
        ) (_: {
          serviceConfig = {
            CPUWeight = 25;
            IOWeight = 25;
            MemoryHigh = "1G";
          };
        });
      virtualisation.docker.daemon.settings.log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };
}
