-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.autoformat = false
vim.o.termguicolors = true
vim.o.background = "dark"
vim.o.cmdheight = 10
vim.o.clipboard = ""
vim.o.cursorline = false

vim.opt.smartcase = true
vim.opt.ignorecase = true

vim.filetype.add({
  extension = {
    mdx = "mdx",
  },
})
