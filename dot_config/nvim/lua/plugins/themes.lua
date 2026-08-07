return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavor = "macchiato", -- specify the flavor
        term_colors = true, -- sets terminal colors (e.g. `g:terminal_color_0`)
        background = {
          light = "latte",
          dark = "macchiato",
        },
        transparent_background = true, -- enable transparent background
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin", -- specify the desired colorscheme
    }
  }
}
