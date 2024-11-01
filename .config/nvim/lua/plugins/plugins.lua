return {
    "nvim-telescope/telescope.nvim",
    dependencies = { 'nvim-lua/plenary.nvim', "nvim-treesitter/nvim-treesitter" },
    "github/copilot.vim",
    "askfiy/visual_studio_code",
    priority = 100,
    config = function()
        vim.cmd([[colorscheme visual_studio_code]])
    end,
    "dstein64/nvim-scrollview",
    opts = {},
    "nvim-tree/nvim-web-devicons",
}
