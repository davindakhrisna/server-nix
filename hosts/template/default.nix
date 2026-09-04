{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.template = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {inherit inputs self;};
          backupFileExtension = "backup";
          sharedModules = [
            inputs.nvf.homeManagerModules.default
          ];
        };
      }
      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware.nix

      # System modules (base, hardware, utils, homelab services)
      self.nixosModules.system

      # Host-specific Configuration
      ({pkgs, ...}: {
        networking.hostName = "template"; # CHANGEME: Hostname
        time.timeZone = "Asia/Jakarta"; # CHANGEME: Timezone
        i18n.defaultLocale = "en_US.UTF-8";

        # User Account (System-level)
        users.users.yourusername = {
          # CHANGEME: Username
          isNormalUser = true;
          shell = pkgs.zsh;
          extraGroups = [
            "wheel"
            "networkmanager"
            "docker"
          ];
          openssh.authorizedKeys.keys = [
            # PASTE YOUR MAIN LAPTOP'S SSH PUBLIC KEY HERE:
            # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@laptop"
          ];
        };

        # Homelab Services Suite
        homelab = {
          ssh.enable = true;
          immich.enable = true;
          glance.enable = true;
          vaultwarden.enable = true;
          obsidianSync.enable = true;
          nas.enable = true;
        };

        # Hardware & Flake Path
        var = {
          flakePath = "/etc/nixos"; # CHANGEME: Path to your flake repository
          cpu = "intel"; # "intel" or "amd"
          gpu = null; # "nvidia", "amd", "intel", or null
          dualBoot.enable = false;
        };

        # User Configuration (Home Manager level)
        home-manager.users.yourusername = {...}: {
          imports = with self.homeModules; [
            home-manager
            shell
            dev
          ];
        };

        system.stateVersion = "26.05";
      })
    ];
  };
}
