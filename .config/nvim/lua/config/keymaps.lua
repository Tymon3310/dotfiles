-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local api = vim.api
local map = vim.keymap.set

map("i", "<C-z>", "<Esc>:undo<CR>a", { desc = "Undo", remap = false })
map("i", "<C-y>", "<Esc>:redo<CR>a", { desc = "redo", remap = false })
api.nvim_set_keymap("i", "<C-a>", "<Esc>V", { noremap = true })

map("n", "%", ":source %<CR>", { desc = "Source current config", noremap = true })

api.nvim_set_keymap("c", "<C-l>", "C-u", { noremap = true })

map("i", "<C-/>", "<Esc>gcc<CR>i", { desc = "Comment one line", remap = true })
map("v", "<C-/>", "<Esc>gc<CR>", { desc = "Comment visual selection", remap = true })
