{
  flake.homeModules.home-manager = {
    config,
    ...
  }: {
    xdg.enable = true;

    home = {
      stateVersion = "26.05";

      sessionVariables = {
        EDITOR = "nvim";

        # Shell & tool history / configs
        HISTFILE = "$HOME/.local/state/bash/history";
        WGETRC = "$HOME/.config/wgetrc";
        DOCKER_CONFIG = "$HOME/.config/docker";
        SQLITE_HISTORY = "$HOME/.local/state/sqlite_history";

        # Rust
        CARGO_HOME = "$HOME/.local/share/cargo";
        RUSTUP_HOME = "$HOME/.local/share/rustup";
      };

      # Prevent Home Manager from linking legacy dotfiles directly in $HOME root
      file = {
        ".zshenv".enable = false;
      };
    };

    programs.home-manager.enable = true;
  };
}
