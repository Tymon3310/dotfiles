return {

  { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },

  { "Mofiqul/vscode.nvim" },

  -- Configure LazyVim to load vscode
  {
    "LazyVim/LazyVim",
    requires = { "Mofiqul/vscode.nvim" },
    opts = {
      colorscheme = "vscode",
    },
  },
  {
    "kevinoid/vim-jsonc",
  },
  {
    "kmonad/kmonad-vim",
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    opts = {
      sources = {
        "filesystem",
        "buffers",
        "git_status",
        "document_symbols",
      },
      auto_clean_after_session_restore = true, -- Automatically clean up broken neo-tree buffers saved in sessions
      close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
      default_source = "filesystem", -- you can choose a specific source `last` here which indicates the last used source
      enable_diagnostics = true,
      enable_git_status = true,
      enable_modified_markers = true, -- Show markers for files with unsaved changes.
      enable_opened_markers = true, -- Enable tracking of opened files. Required for `components.name.highlight_opened_files`
      icon = {
        git_status = {
          symbols = {
            -- Change type
            added = "✚", -- NOTE: you can set any of these to an empty string to not show them
            deleted = "✖",
            modified = "",
            renamed = "󰁕",
            -- Status type
            untracked = "",
            ignored = "",
            unstaged = "󰄱",
            staged = "",
            conflict = "",
          },
          align = "right",
        },
      },
      filesystem = {
        filtered_items = {
          visible = true, -- when true, they will just be displayed differently than normal items
          hide_dotfiles = true,
          hide_gitignored = true,
          hide_hidden = true, -- only works on Windows for hidden files/directories
          hide_by_name = {
            ".DS_Store",
            "thumbs.db",
            --"node_modules",
          },
          hide_by_pattern = {
            --"*.meta",
            --"*/src/*/tsconfig.json",
          },
          always_show = { -- remains visible even if other settings would normally hide it
            --"".gitignored",
          },
          always_show_by_pattern = { -- uses glob style patterns
            --"".env*",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            --"".DS_Store",
            --"thumbs.db",
          },
          never_show_by_pattern = { -- uses glob style patterns

            --"".null-ls_*",
          },
        },
      },
    },
  },
}
