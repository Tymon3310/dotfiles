-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })
map("i", "<C-a>", "<Esc>V", { desc = "Select line" })

map("n", "<leader>cs", ":source %<CR>", { desc = "Source current file" })

map("c", "<C-l>", "<C-u>", { desc = "Clear command line" })

map("i", "<C-/>", "<C-o>gcc", { desc = "Comment one line", remap = true })
map("i", "<C-_>", "<C-o>gcc", { desc = "Comment one line", remap = true })
map("x", "<C-/>", "gc", { desc = "Comment visual selection", remap = true })
map("x", "<C-_>", "gc", { desc = "Comment visual selection", remap = true })
