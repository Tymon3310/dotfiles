return {
  {
    "folke/snacks.nvim",
    opts = function()
      -- 1. Calculate the greeting BEFORE building the config
      local datetime = os.date(" %Y-%m-%d   %H:%M:%S")
      local hour = tonumber(os.date("%H"))
      local mesg
      local username = os.getenv("USER") or os.getenv("USERNAME") or "User"

      if hour >= 2 and hour < 6 then
        mesg = "Dreaming..󰒲 󰒲 "
      elseif hour >= 6 and hour < 12 then
        mesg = "🌅 Hi " .. username .. ", Good Morning ☀️"
      elseif hour >= 12 and hour < 18 then
        mesg = "🌞 Hi " .. username .. ", Good Afternoon ☕️"
      elseif hour >= 18 and hour < 22 then
        mesg = "🌆 Hi " .. username .. ", Good Evening 🌙"
      else
        mesg = "Hi " .. username .. ", it's getting late, get some sleep 😴"
      end

      local greeting = mesg .. " | " .. datetime

      -- 2. BULLETPROOF HIGHLIGHTS:
      -- Define the exact VS Code Dark Blue (#569CD6) so it never fails.
      -- (If you use VS Code Light, change this hex to "#007ACC")
      vim.api.nvim_set_hl(0, "MyDashboardBlue", { fg = "#569CD6" })

      -- Link the default Snacks ASCII art highlight to our blue so the giant NeoVim logo matches
      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { link = "MyDashboardBlue" })

      -- 3. Return the snacks configuration
      return {
        dashboard = {
          enabled = true,
          preset = {
            header = [[
    NeoVim
    ┌───────────────────────────────────────────────────────────────────────────────┐
    │ ████████╗██╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗██████╗ ██████╗  ██╗ ██████╗  │
    │ ╚══██╔══╝╚██╗ ██╔╝████╗ ████║██╔═══██╗████╗  ██║╚════██╗╚════██╗███║██╔═████╗ │
    │    ██║    ╚████╔╝ ██╔████╔██║██║   ██║██╔██╗ ██║ █████╔╝ █████╔╝╚██║██║██╔██║ │
    │    ██║     ╚██╔╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║ ╚═══██╗ ╚═══██╗ ██║████╔╝██║ │
    │    ██║      ██║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██████╔╝██████╔╝ ██║╚██████╔╝ │
    │    ╚═╝      ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═════╝  ╚═╝ ╚═════╝  │
    └───────────────────────────────────────────────────────────────────────────────┘
            ]],
            keys = {
              { icon = " ", key = "f", desc = "Find File", action = ":lua LazyVim.pick()()" },
              { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
              { icon = " ", key = "r", desc = "Recent Files", action = ":lua LazyVim.pick('oldfiles')()" },
              { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
              { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
          sections = {
            { section = "header" },
            {
              align = "center",
              padding = 1,
              text = { { greeting, "MyDashboardBlue" } },
            },
            { section = "keys",   gap = 1, padding = 1 },
            { section = "startup" },
          },
        },
      }
    end,
  },
}
