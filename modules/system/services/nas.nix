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

      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = lib.attrNames (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);
        description = "Local accounts allowed to use the NAS; set their Samba passwords with smbpasswd -a.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.nas.members = cfg.users;
      systemd.tmpfiles.rules = [
        "d ${cfg.sharesPath} 2770 root nas -"
      ];

      # Samba file sharing & Network Discovery
      services = {
        samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "server string" = "NixOS file server";
              "security" = "user";
              # Only allow private LAN subnets and Tailscale (100.x.y.z)
              "hosts allow" = "192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 100.64.0.0/10 127.0.0.1 ::1";
              "hosts deny" = "0.0.0.0/0";
              "map to guest" = "never";
              "server min protocol" = "SMB2_10";
            };
            nas = {
              "path" = cfg.sharesPath;
              "browseable" = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "valid users" = lib.concatStringsSep " " cfg.users;
              "force group" = "nas";
              "create mask" = "0660";
              "force create mode" = "0660";
              "directory mask" = "2770";
              "force directory mode" = "2770";
              "comment" = "Shared Storage";
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
