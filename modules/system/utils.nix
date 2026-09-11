{
  flake.nixosModules.utils = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      # Monitoring & Diagnostics
      htop
      btop
      iotop
      nix-index

      # Archives & Utilities
      unzip
      wget
      curl
      rsync
      tmux
      psmisc # provides killall, pstree, fuser

      # Language
      python3
      nodejs
    ];
  };
}
