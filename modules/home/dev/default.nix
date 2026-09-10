{
  flake.homeModules.dev = {
    config,
    pkgs,
    inputs,
    ...
  }: {
    imports = [
      ./_nvf.nix
      inputs.nix-index-database.homeModules.nix-index
    ];

    programs = {
      nix-index-database.comma.enable = true;

      git = {
        enable = true;
        settings = {
          init.defaultBranch = "main";
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
        # Language toolchains live in per-project devShells (direnv + use flake)
        # This global list is only for editor/CLI tools useful everywhere.

        # Universal Dev CLI
        uv # Python: venvs & pip replacement (pip installs into the nix store otherwise)
        sqlite

        # Containers & Networking Dev Tools
        lazydocker
        netcat-gnu

        # Core CLI & TUI Dev Tools
        lazygit
        jq
        alejandra
        nixfmt
      ];

      sessionPath = ["$HOME/.local/share/go/bin" "$HOME/.local/bin"];
      sessionVariables = {
        # Go
        GOPATH = "$HOME/.local/share/go";
        GOMODCACHE = "$HOME/.cache/go/mod";

        # Node & NPM (npm i -g works into ~/.local instead of the read-only store)
        NPM_CONFIG_USERCONFIG = "$HOME/.config/npm/npmrc";
        NPM_CONFIG_CACHE = "$HOME/.cache/npm";
        NPM_CONFIG_PREFIX = "$HOME/.local";
        NODE_REPL_HISTORY = "$HOME/.local/state/node_repl_history";

        # Python
        PYTHONSTARTUP = "$HOME/.config/python/pythonrc";
        IPYTHONDIR = "$HOME/.config/ipython";
        JUPYTER_CONFIG_DIR = "$HOME/.config/jupyter";
      };
    };
  };
}
