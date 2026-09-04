{pkgs, ...}: {
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.nvf = {
    enable = true;
    enableManpages = true;

    settings = {
      vim = {
        viAlias = true;
        vimAlias = true;
        globals.mapleader = " ";
        globals.maplocalleader = " ";

        # Editor Options
        options = {
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = true;
          smartindent = true;
          number = true;
          relativenumber = true;
          cursorline = true;
          mouse = "a";
          clipboard = "unnamedplus";
          undofile = true;
          signcolumn = "yes";
          scrolloff = 8;
          sidescrolloff = 8;
          splitbelow = true;
          splitright = true;
          termguicolors = true;
          wrap = false;
          timeoutlen = 300;
        };

        # Theme & Visual Aesthetics
        theme = {
          enable = true;
          name = "catppuccin";
          style = "mocha";
          transparent = true;
        };

        # Statusline & Mini Suite
        mini = {
          statusline.enable = true;
          icons.enable = true;
          indentscope.enable = true;
          ai.enable = true;
        };

        extraPlugins = {
          mini-base16 = {
            package = pkgs.vimPlugins.mini-base16;
          };
        };

        # Static OLED Monochrome Palette
        luaConfigRC.theme = ''
          local mini_base16 = require('mini.base16')
          mini_base16.setup({
            palette = {
              base00 = '#000000', -- Default Background (True OLED Black)
              base01 = '#121212', -- Lighter Background (Statusline/Sidebar)
              base02 = '#262626', -- Selection Background
              base03 = '#737373', -- Comments & Line Numbers (Crisp Silver Grey)
              base04 = '#a3a3a3', -- Dark Foreground (Status bar elements)
              base05 = '#f5f5f5', -- Default Foreground (Crisp White Text)
              base06 = '#ffffff', -- Light Foreground
              base07 = '#ffffff', -- Lightest Accent
              base08 = '#ef4444', -- Variables & Errors (Red)
              base09 = '#f97316', -- Constants & Numbers (Orange)
              base0A = '#eab308', -- Classes & Types (Amber/Yellow)
              base0B = '#22c55e', -- Strings (Green)
              base0C = '#06b6d4', -- Regex & Special (Cyan)
              base0D = '#38bdf8', -- Functions & Methods (Sky/Blue)
              base0E = '#c084fc', -- Keywords & Storage (Purple/Magenta)
              base0F = '#e4e4e7', -- Delimiters & Accents (Silver)
            },
            use_icons = true,
          })
        '';

        # Tabline / Bufferline
        tabline.nvimBufferline = {
          enable = true;
        };

        # Visual Addons
        visuals = {
          nvim-web-devicons.enable = true;
          indent-blankline.enable = true;
          rainbow-delimiters.enable = true;
        };

        # UI Components
        ui = {
          borders.enable = true;
          colorizer.enable = true;
          noice.enable = true;
          fastaction.enable = true;
        };

        # Notification Popups
        notify.nvim-notify.enable = true;

        # File Explorer & Fuzzy Search
        filetree.neo-tree = {
          enable = true;
        };

        telescope = {
          enable = true;
        };

        # Autocompletion (nvim-cmp) & Snippets
        autocomplete.nvim-cmp = {
          enable = true;
          sources = {
            buffer = "[Buffer]";
            lsp = "[LSP]";
            path = "[Path]";
            treesitter = "[Treesitter]";
          };
        };

        snippets.luasnip.enable = true;

        # LSP (Language Server Protocol)
        lsp = {
          enable = true;
          formatOnSave = true;
          lightbulb.enable = true;
          lspkind.enable = true;
          trouble.enable = true;
        };

        # Treesitter
        treesitter = {
          enable = true;
          autotagHtml = true;
          context.enable = true;
        };

        # Git Integration
        git = {
          enable = true;
          gitsigns = {
            enable = true;
            codeActions.enable = true;
          };
        };

        # Utility & Keymap Helper
        binds = {
          whichKey.enable = true;
          cheatsheet.enable = true;
        };

        utility = {
          surround.enable = true;
          motion.flash-nvim.enable = true;
          diffview-nvim.enable = true;
        };

        autopairs.nvim-autopairs.enable = true;
        comments.comment-nvim.enable = true;

        # Rich Multi-Language Support
        languages = {
          enableTreesitter = true;
          enableFormat = true;
          enableExtraDiagnostics = true;

          nix.enable = true;
          markdown.enable = true;
          bash.enable = true;
          lua.enable = true;
          rust.enable = true;
          tsx.enable = true;
          go.enable = true;
          python.enable = true;
          html.enable = true;
          css.enable = true;
          yaml.enable = true;
          json.enable = true;
          toml.enable = true;
        };

        # Intuitive Custom Keymaps
        keymaps = [
          # File Tree & Finder
          {
            key = "<leader>e";
            mode = "n";
            action = ":Neotree toggle<CR>";
            desc = "Toggle File Explorer";
          }
          {
            key = "<leader>ff";
            mode = "n";
            action = ":Telescope find_files<CR>";
            desc = "Find Files";
          }
          {
            key = "<leader>fg";
            mode = "n";
            action = ":Telescope live_grep<CR>";
            desc = "Live Grep";
          }
          {
            key = "<leader>fb";
            mode = "n";
            action = ":Telescope buffers<CR>";
            desc = "Find Buffers";
          }
          {
            key = "<leader>fh";
            mode = "n";
            action = ":Telescope help_tags<CR>";
            desc = "Help Tags";
          }

          # Buffer Navigation
          {
            key = "<Tab>";
            mode = "n";
            action = ":bnext<CR>";
            desc = "Next Buffer";
          }
          {
            key = "<S-Tab>";
            mode = "n";
            action = ":bprevious<CR>";
            desc = "Previous Buffer";
          }
          {
            key = "<leader>bd";
            mode = "n";
            action = ":bdelete<CR>";
            desc = "Close Buffer";
          }

          # Window Splits & Navigation
          {
            key = "<leader>sv";
            mode = "n";
            action = ":vsplit<CR>";
            desc = "Split Vertical";
          }
          {
            key = "<leader>sh";
            mode = "n";
            action = ":split<CR>";
            desc = "Split Horizontal";
          }
          {
            key = "<C-h>";
            mode = "n";
            action = "<C-w>h";
            desc = "Focus Left Window";
          }
          {
            key = "<C-j>";
            mode = "n";
            action = "<C-w>j";
            desc = "Focus Down Window";
          }
          {
            key = "<C-k>";
            mode = "n";
            action = "<C-w>k";
            desc = "Focus Up Window";
          }
          {
            key = "<C-l>";
            mode = "n";
            action = "<C-w>l";
            desc = "Focus Right Window";
          }

          # Diagnostics & Trouble
          {
            key = "<leader>xx";
            mode = "n";
            action = ":Trouble diagnostics toggle<CR>";
            desc = "Diagnostics (Trouble)";
          }

          # Quick Save & Quit
          {
            key = "<leader>w";
            mode = "n";
            action = ":w<CR>";
            desc = "Save File";
          }
          {
            key = "<leader>q";
            mode = "n";
            action = ":q<CR>";
            desc = "Quit";
          }
        ];
      };
    };
  };
}
