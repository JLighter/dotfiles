-- Fond transparent, quel que soit le colorscheme actif.
--
-- Catppuccin sait le faire nativement (transparent_background), mais les thèmes
-- livrés par Omarchy — gruvbox et les autres — non, et ils changent à chaque
-- `omarchy theme set`. Plutôt que de configurer chaque thème, on neutralise le
-- fond des groupes concernés après chaque application de colorscheme : ça vaut
-- pour macOS comme pour Omarchy, aujourd'hui et pour les thèmes à venir.

local groups = {
  -- Corps de l'éditeur
  "Normal",
  "NormalNC",
  "EndOfBuffer",
  "SignColumn",
  "LineNr",
  "FoldColumn",
  -- Flottants et bordures
  "NormalFloat",
  "FloatBorder",
  "FloatTitle",
  -- Barres
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  -- Plugins de l'install
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeEndOfBuffer",
  "TelescopeNormal",
  "TelescopeBorder",
  "WhichKeyFloat",
  "SnacksNormal",
  "SnacksNormalNC",
}

local function strip_background()
  for _, group in ipairs(groups) do
    -- link = false résout les groupes liés : sans lui, on récupérerait
    -- { link = "Autre" } et réécrire le groupe casserait le lien.
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    if ok and hl then
      hl.bg = nil
      hl.ctermbg = nil
      pcall(vim.api.nvim_set_hl, 0, group, hl)
    end
  end
end

return {
  {
    "LazyVim/LazyVim",
    init = function()
      -- Posé dans init(), donc avant que LazyVim n'applique le colorscheme :
      -- le premier rendu est déjà transparent, sans flash de fond opaque.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("UserTransparency", { clear = true }),
        callback = strip_background,
      })
    end,
  },
}
