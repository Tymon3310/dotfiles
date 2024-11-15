return {

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
    "nvimdev/dashboard-nvim",
    lazy = false, -- As https://github.com/nvimdev/dashboard-nvim/pull/450, dashboard-nvim shouldn't be lazy-loaded to properly handle stdin.
    opts = function()
      local logo = [[
       ┌───────────────────────────────────────────────────────────────────────────────┐
       │ ████████╗██╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗██████╗ ██████╗  ██╗ ██████╗  │
       │ ╚══██╔══╝╚██╗ ██╔╝████╗ ████║██╔═══██╗████╗  ██║╚════██╗╚════██╗███║██╔═████╗ │
       │    ██║    ╚████╔╝ ██╔████╔██║██║   ██║██╔██╗ ██║ █████╔╝ █████╔╝╚██║██║██╔██║ │
       │    ██║     ╚██╔╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║ ╚═══██╗ ╚═══██╗ ██║████╔╝██║ │
       │    ██║      ██║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██████╔╝██████╔╝ ██║╚██████╔╝ │
       │    ╚═╝      ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═════╝  ╚═╝ ╚═════╝  │
       └───────────────────────────────────────────────────────────────────────────────┘
          ]]

      logo = string.rep("\n", 2) .. logo .. "\n\n"

      local opts = {
        theme = "doom",
        hide = {
          -- this is taken care of by lualine
          -- enabling this messes up the actual laststatus setting after loading a file
          statusline = false,
        },
        config = {
          header = vim.split(logo, "\n"),
                    -- stylua: ignore
                    center = {
                        { action = 'lua LazyVim.pick()()', desc = " Find File", icon = " ", key = "f" },
                        { action = "ene | startinsert", desc = " New File", icon = " ", key = "n" },
                        { action = 'lua LazyVim.pick("oldfiles")()', desc = " Recent Files", icon = " ", key = "r" },
                        { action = 'lua LazyVim.pick("live_grep")()', desc = " Find Text", icon = " ", key = "g" },
                        { action = 'lua LazyVim.pick.config_files()()', desc = " Config", icon = " ", key = "c" },
                        { action = 'lua require("persistence").load()', desc = " Restore Session", icon = " ", key = "s" },
                        { action = "LazyExtras", desc = " Lazy Extras", icon = " ", key = "x" },
                        { action = "Lazy", desc = " Lazy", icon = "󰒲 ", key = "l" },
                        { action = function() vim.api.nvim_input("<cmd>qa<cr>") end, desc = " Quit", icon = " ", key = "q" },
                    },
          footer = function()
            local stats = require("lazy").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
            return { "⚡ Neovim loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms" }
          end,
        },
      }

      for _, button in ipairs(opts.config.center) do
        button.desc = button.desc .. string.rep(" ", 43 - #button.desc)
        button.key_format = "  %s"
      end

      -- open dashboard after closing lazy
      if vim.o.filetype == "lazy" then
        vim.api.nvim_create_autocmd("WinClosed", {
          pattern = tostring(vim.api.nvim_get_current_win()),
          once = true,
          callback = function()
            vim.schedule(function()
              vim.api.nvim_exec_autocmds("UIEnter", { group = "dashboard" })
            end)
          end,
        })
      end

      return opts
    end,
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
