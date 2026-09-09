{
  flake.nixosModules.services-immich = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.immich;
  in {
    options.homelab.immich = {
      enable = lib.mkEnableOption "Immich self-hosted photo and video backup solution";

      port = lib.mkOption {
        type = lib.types.port;
        default = 2283;
        description = "Port on which Immich web and API listens";
      };

      mediaLocation = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/immich";
        description = "Storage path for photo and video uploads";
      };
    };

    config = lib.mkIf cfg.enable {
      services.immich = {
        enable = true;
        host = "127.0.0.1";
        inherit (cfg) port mediaLocation;
        openFirewall = false;
      };
    };
  };
}
