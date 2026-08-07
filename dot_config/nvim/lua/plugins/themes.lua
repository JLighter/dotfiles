-- Sur Omarchy, `omarchy theme set` réécrit
-- ~/.config/omarchy/current/theme/neovim.lua, qui est déjà une spec lazy.nvim
-- (le plugin de colorscheme + l'override LazyVim qui l'active). On le charge
-- tel quel plutôt que d'imposer Catppuccin.
--
-- Ailleurs — macOS, ou Omarchy avant le premier theme set — le fichier n'existe
-- pas et on retombe sur Catppuccin, qui suit le clair/sombre du système.
--
-- Après un changement de thème, le plugin demandé change : `:Lazy sync` peut
-- être nécessaire pour l'installer. Le hook theme-set d'Omarchy ne recharge pas
-- les instances de Neovim déjà ouvertes.

local omarchy_theme = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")

if (vim.uv or vim.loop).fs_stat(omarchy_theme) then
  local ok, spec = pcall(dofile, omarchy_theme)
  if ok and type(spec) == "table" then
    return spec
  end
  vim.notify("Thème Omarchy illisible, repli sur Catppuccin", vim.log.levels.WARN)
end

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
    },
  },
}
