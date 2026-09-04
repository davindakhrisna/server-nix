{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      ./_hardware.nix
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

      # System modules (base, hardware, utils, homelab services)
      self.nixosModules.system

      # Host-specific Configuration
      ({pkgs, ...}: {
        networking.hostName = "homelab";
        time.timeZone = "Asia/Jakarta";
        i18n.defaultLocale = "en_US.UTF-8";

        # User Account (System-level)
        users.users.kryisnn = {
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
          nas.enable = true;

          obsidianSync = {
            enable = true;
            adminUser = "admin";
            adminPassword = "admin"; # Change this from default!
          };
        };

        # Hardware & Flake Path
        var = {
          flakePath = "/home/kryisnn/.config/flint"; # Path to your flint flake repository
          cpu = "intel";
          gpu = null; # Set to "nvidia", "amd", or "intel" if laptop has dedicated GPU
          dualBoot.enable = false;
        };

        # User Configuration (Home Manager level)
        home-manager.users.kryisnn = {...}: {
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
