{
  flake.nixosModules.services-vaultwarden = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.vaultwarden;
  in {
    options.homelab.vaultwarden = {
      enable = lib.mkEnableOption "Vaultwarden self-hosted Bitwarden compatible password manager";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8222;
        description = "Port on which Vaultwarden server listens";
      };

      allowSignups = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow new user registrations (can be disabled after creating your account)";
      };
    };

    config = lib.mkIf cfg.enable {
      services.vaultwarden = {
        enable = true;
        dbBackend = "sqlite";
        config = {
          ROCKET_ADDRESS = "0.0.0.0";
          ROCKET_PORT = cfg.port;
          SIGNUPS_ALLOWED = cfg.allowSignups;
        };
      };

      networking.firewall.allowedTCPPorts = [cfg.port];
    };
  };
}
