-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local api = vim.api
local map = vim.keymap.set

map({ "i", "n" }, "<C-z>", "<Esc>:undo<CR>a", { desc = "Undo", remap = false })
map("i", "<C-y>", "<Esc>:redo<CR>a", { desc = "redo", remap = false })
map("n", "r", "<Esc>:redo<CR>", { desc = "redo", remap = false })
api.nvim_set_keymap("i", "<C-a>", "<Esc>V", { noremap = true })

map("n", "%", ":source %<CR>", { desc = "Source current config", noremap = true })

api.nvim_set_keymap("c", "<C-l>", "C-u", { noremap = true })

map("i", "<C-/>", "<Esc>gcc<CR>", { desc = "Comment one line", remap = true })
map("v", "<C-/>", "gc<CR>", { desc = "Comment visual selection", remap = true })

map("i", "C-E", ":Copilot suggestion dismiss<CR>", { desc = "Dismiss Copilot suggestion", remap = true })
-- map({ "i", "n" }, "<CR>", "<ESC>:Copilot suggestion dismiss<CR><ESC>o", { desc = "Insert newline below", remap = true })

map("i", "C- TAB ", ":Copilot sugestion accept<CR>", { desc = "Accept Copilot suggestion", remap = true })

map("n", "qq", "<nop>", { remap = true })
