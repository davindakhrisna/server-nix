{
  flake.homeModules.utils-zsh = {
    pkgs,
    lib,
    config,
    ...
  }: {
    home.sessionVariables = {
      COLORTERM = "truecolor";
      MANPAGER = "bat -l man -p";
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --strip-cwd-prefix --hidden --exclude .git";
      fileWidget.command = "fd --type f --strip-cwd-prefix --hidden --exclude .git";
      changeDirWidget.command = "fd --type d --strip-cwd-prefix --hidden --exclude .git";
      defaultOptions = [
        "--height 45%"
        "--layout=reverse"
        "--border"
        "--inline-info"
      ];
      historyWidget.options = [
        "--sort"
        "--exact"
      ];
    };

    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      autocd = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;

      plugins = [
        {
          name = "zsh-vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];

      history = {
        path = "${config.xdg.dataHome}/zsh/history";
        ignoreDups = true;
        findNoDups = true;
        expireDuplicatesFirst = true;
        ignoreSpace = true;
        append = true;
        save = 10000;
        size = 10000;
      };

      setOptions = [
        "NOBEEP"
        "AUTOCD"
        "NUMERIC_GLOB_SORT"
      ];

      profileExtra = lib.optionalString (config.home.sessionPath != []) ''
        export PATH="$PATH''${PATH:+:}${lib.concatStringsSep ":" config.home.sessionPath}"
      '';

      shellAliases = {
        # Change default
        vim = "nvim";
        vi = "nvim";
        mkdir = "mkdir -p";
        nix-shell = "nix-shell --command zsh";
        diff = "diff --color=auto";
        tree = "eza --icons=always --tree --no-quotes";

        # Shortcuts
        notes = "nvim ~/Notes/index.md --cmd 'cd ~/notes' -c ':lua Snacks.picker.smart()'";

        # Git
        g = "lazygit";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gpl = "git pull";
        gs = "git status";
        gd = "git diff";
        gco = "git checkout";
        gcb = "git checkout -b";
        gbr = "git branch";
        grs = "git reset HEAD~1";
        grh = "git reset --hard HEAD~1";
        gaa = "git add .";
        gcm = "git commit -m";

        # Nix & System Management (nh)
        nos = "nh os switch";
        not = "nh os test";
        nob = "nh os boot";
        nclean = "nh clean all";
        ncheck = "nix flake check \${FLINT_DIR:-\$HOME/.config/flint} --no-build";
        nup = "nix flake update --flake \${FLINT_DIR:-\$HOME/.config/flint}";

        # Original binaries
        ocat = "/run/current-system/sw/bin/cat";
        ols = "/run/current-system/sw/bin/ls";
        ocd = "builtin cd";

        # Common typos
        clera = "clear";
        celar = "clear";
        claer = "clear";
        sl = "ls";
      };

      initContent = lib.mkMerge [
        (lib.mkOrder 550 ''
          function zvm_config() {
            ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
            ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
            ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK

            ZVM_VI_HIGHLIGHT_BACKGROUND=none
            ZVM_VI_HIGHLIGHT_FOREGROUND=none
            ZVM_VI_HIGHLIGHT_EXTRASTYLE=none
          }
        '')
        ''
          # Static OLED Monochrome Colors for FZF & Shell
          export FZF_DEFAULT_OPTS=" \
          --color=bg+:#1a1a1a,bg:#000000,spinner:#ffffff,hl:#ef4444 \
          --color=fg:#f5f5f5,header:#ffffff,info:#ffffff,pointer:#ffffff \
          --color=marker:#22c55e,fg+:#ffffff,prompt:#ffffff,hl+:#f87171 \
          --height 45% --layout=reverse --border --inline-info"

          # Modern CLI Tool Reminders
          unalias cd cat ls df grep find 2>/dev/null || true

          _hint() {
            if [[ -o interactive || -t 1 || -t 2 ]]; then
              echo -e "\033[1;33m💡 [Tip]\033[0m Use \033[1;36m$1\033[0m instead of \033[1;31m$2\033[0m"
            fi
          }

          function cd {
            builtin cd "$@"
            local ret=$?
            _hint "z" "cd"
            return $ret
          }

          function cat {
            command cat "$@"
            local ret=$?
            _hint "bat" "cat"
            return $ret
          }

          function ls {
            command ls "$@"
            local ret=$?
            _hint "eza" "ls"
            return $ret
          }

          function df {
            command df "$@"
            local ret=$?
            _hint "duf" "df"
            return $ret
          }

          function grep {
            command grep "$@"
            local ret=$?
            _hint "rg (ripgrep)" "grep"
            return $ret
          }

          function find {
            command find "$@"
            local ret=$?
            _hint "fd" "find"
            return $ret
          }

          # Suffix Aliases
          alias -s {nix,md,txt,yml,yaml,go}=nvim
          alias -s {json,jsonl}=jless
          alias -s {csv,tsv,parquet,pqt,arrow,db,sqlite,xls,xlsx,xlsm,xlsb,fwf}=tw

          # Global Aliases
          alias -g G="| rg"
          alias -g L="| less"
          alias -g V="| nvim"
          alias -g H="| head"
          alias -g T="| tail"
          alias -g JQ="| jq"
          alias -g NE="2>/dev/null"
          alias -g ND=">/dev/null"
          alias -g NUL=">/dev/null 2>&1"

          autoload zmv # Mv for multiple files

          zstyle ':completion:*' menu select
          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

          zvm_after_init() {
            bindkey '^[[1;5C' forward-word
            bindkey '^[[1;5D' backward-word
            bindkey '^R' fzf-history-widget
            bindkey '^T' fzf-file-widget
            bindkey '^[c' fzf-cd-widget
            bindkey '^[[A' history-substring-search-up
            bindkey '^[[B' history-substring-search-down
          }
        ''
      ];
    };
  };
}
