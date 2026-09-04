{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      inputs.disko.nixosModules.disko
      ./_disko.nix
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
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJH9jDDmY066+eqWJq6HZtJuhysL3CAL29HsSM1rtSou kris@windows"
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
