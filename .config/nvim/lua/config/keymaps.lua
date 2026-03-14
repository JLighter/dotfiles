-- This file is automatically loaded by lazyvim.config.init

-- DO NOT USE `LazyVim.safe_keymap_set` IN YOUR OWN CONFIG!!
-- use `vim.keymap.set` instead
local map = LazyVim.safe_keymap_set

map("n", "<leader>/", ":vsplit<CR>", { desc = "Split window right", remap = true, silent = true })
