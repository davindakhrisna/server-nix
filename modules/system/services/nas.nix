{
  flake.nixosModules.services-nas = {
    config,
    lib,
    ...
  }: let
    cfg = config.homelab.nas;
  in {
    options.homelab.nas = {
      enable = lib.mkEnableOption "Samba NAS file sharing and network discovery";

      sharesPath = lib.mkOption {
        type = lib.types.path;
        default = "/srv/nas";
        description = "Path to the shared NAS storage pool";
      };
    };

    config = lib.mkIf cfg.enable {
      # Ensure the shared storage directory exists with open local permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.sharesPath} 0777 root root -"
      ];

      # Samba file sharing & Network Discovery
      services = {
        samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "server string" = "Homelab NAS";
              "netbios name" = "HOMELAB";
              "security" = "user";
              # Only allow private LAN subnets and Tailscale (100.x.y.z)
              "hosts allow" = "192.168. 10. 172.16. 100. 127.0.0.1 localhost";
              "hosts deny" = "0.0.0.0/0";
              "guest account" = "nobody";
              "map to guest" = "bad user";
            };
            nas = {
              "path" = cfg.sharesPath;
              "browseable" = "yes";
              "read only" = "no";
              "guest ok" = "yes";
              "create mask" = "0664";
              "directory mask" = "0775";
              "comment" = "Homelab Shared Storage";
            };
          };
        };

        # Windows Network Discovery (WSDD)
        samba-wsdd = {
          enable = true;
          openFirewall = true;
        };

        # mDNS (Bonjour / Apple / Linux auto-discovery)
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
          };
        };
      };
    };
  };
}
