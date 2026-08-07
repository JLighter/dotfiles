return {
  "alexghergh/nvim-tmux-navigation",
  cmd = { "NvimTmuxNavigateUp", "NvimTmuxNavigateDown", "NvimTmuxNavigateLeft", "NvimTmuxNavigateRight" },
  keys = {
    { "<C-j>", ":NvimTmuxNavigateDown <CR>", mode="n", desc = "Move to bottom tmux pane", nowait = true, silent = true, noremap = true },
    { "<C-k>", ":NvimTmuxNavigateUp <CR>", mode="n", desc = "Move to top tmux pane", nowait = true, silent = true, noremap = true },
    { "<C-l>", ":NvimTmuxNavigateRight <CR>", mode="n", desc = "Move to right tmux pane", nowait = true, silent = true, noremap = true },
    { "<C-h>", ":NvimTmuxNavigateLeft <CR>", mode="n", desc = "Move to left tmux pane", nowait = true, silent = true, noremap = true }
  },
  opts = {
    disabled_when_zoomed = true,
  },
  config = function(_, opts)
    require("nvim-tmux-navigation").setup(opts)
  end,
}
