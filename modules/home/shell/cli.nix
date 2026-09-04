{
  flake.homeModules.utils-cli = {pkgs, ...}: {
    home.packages = with pkgs; [
      # System info & inspection
      fastfetch

      # Modern CLI replacements
      bat # cat
      duf # df
      eza # ls
      ripgrep # grep
      fd # find

      # Media CLI
      yt-dlp
      ffmpeg
    ];

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
