{
  flake.nixosModules.utils = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      # Monitoring & Diagnostics
      htop
      btop
      iotop
      nix-index

      # Archives & Utilities
      socat
      unzip
      wget
      curl
      rsync
      tmux
      psmisc # provides killall, pstree, fuser
    ];
  };
}
