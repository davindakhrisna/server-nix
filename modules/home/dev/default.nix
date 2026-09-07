{
  flake.homeModules.dev = {
    config,
    pkgs,
    osConfig ? {},
    ...
  }: {
    imports = [
      ./_nvf.nix
    ];

    programs = {
      git = {
        enable = true;
        settings = {
          user = {
            name = "davindakhrisna";
            email = "arpeggio.gns@gmail.com";
          };
          init.defaultBranch = "main";
          safe.directory = [(osConfig.var.flakePath or "${config.home.homeDirectory}/.config/config") "*"];
        };
      };

      gh = {
        enable = true;
        gitCredentialHelper.enable = true;
      };

      ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "github.com" = {
            hostname = "github.com";
            user = "git";
            identityFile = "${config.home.homeDirectory}/.ssh/id_github_deploy";
            identitiesOnly = true;
          };
        };
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    home = {
      packages = with pkgs; [
        # Core Build & Compiler Tools
        gcc
        gnumake
        pkg-config

        # Core Database CLI
        sqlite

        # Web & General Dev Languages
        go
        nodejs
        python3

        # Package Managers & Process Runners
        pnpm
        air

        # Containers & Networking Dev Tools
        lazydocker
        netcat-gnu

        # Core CLI & TUI Dev Tools
        lazygit
        jq
        alejandra
        nixfmt
      ];

      sessionPath = ["$HOME/.local/share/go/bin"];
      sessionVariables = {
        # Go
        GOPATH = "$HOME/.local/share/go";
        GOMODCACHE = "$HOME/.cache/go/mod";

        # Node & NPM
        NPM_CONFIG_USERCONFIG = "$HOME/.config/npm/npmrc";
        NPM_CONFIG_CACHE = "$HOME/.cache/npm";
        NODE_REPL_HISTORY = "$HOME/.local/state/node_repl_history";

        # Python
        PYTHONSTARTUP = "$HOME/.config/python/pythonrc";
        IPYTHONDIR = "$HOME/.config/ipython";
        JUPYTER_CONFIG_DIR = "$HOME/.config/jupyter";
      };
    };
  };
}
