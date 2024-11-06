-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local api = vim.api

api.nvim_set_keymap("i", "<C-z>", "<Esc>:undo<CR>a", { noremap = true })
api.nvim_set_keymap("i", "<C-y>", "<Esc>:redo<CR>a", { noremap = true })
api.nvim_set_keymap("i", "<C-a>", "<Esc>V", { noremap = true })

api.nvim_set_keymap("n", "%", ":source %<CR>", { noremap = true })

api.nvim_set_keymap("c", "<C-l>", "C-u", { noremap = true })
