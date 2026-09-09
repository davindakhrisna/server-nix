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
      # Pin json-file explicitly: newer Docker defaults to the journald log
      # driver on systemd hosts, which does not support max-size/max-file and
      # refuses to start if they are set.
      virtualisation.docker.daemon.settings = {
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
      };
    };
  };
}
