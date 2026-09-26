-- <C-h/j/k/l> traverse les splits Neovim, puis franchit le bord vers le pane
-- herdr voisin.
--
-- `~/.config/herdr/config.toml` bind les mêmes touches sur le plugin
-- vim-herdr-navigation. Celui-ci inspecte le process au premier plan du pane
-- focalisé : si c'est (n)vim, il lui réinjecte la touche au lieu de déplacer le
-- focus. Ce fichier est l'autre moitié de l'aller-retour — sans lui, la touche
-- s'arrête au bord de la disposition Neovim.
local M = {}

local function in_herdr()
  return vim.env.HERDR_PANE_ID ~= nil and vim.env.HERDR_PANE_ID ~= ""
end

-- Bouger dans Neovim, et uniquement si la fenêtre n'a pas changé (donc on était
-- déjà au bord), passer la main à herdr. Hors herdr, reste un simple `wincmd`.
local function navigate(wincmd, direction)
  local previous = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)

  if not in_herdr() or vim.api.nvim_get_current_win() ~= previous then
    return
  end

  -- HERDR_BIN_PATH n'est pas garanti (vide sur Omarchy) : le PATH suffit.
  local herdr = vim.env.HERDR_BIN_PATH
  if herdr == nil or herdr == "" then
    herdr = "herdr"
  end

  -- Cibler ce pane explicitement : `--current` désigne le pane focalisé côté
  -- serveur, pas nécessairement celui où tourne ce Neovim.
  vim.fn.system({ herdr, "pane", "focus", "--direction", direction, "--pane", vim.env.HERDR_PANE_ID })
end

function M.setup()
  local opts = { nowait = true, silent = true }
  -- stylua: ignore start
  vim.keymap.set("n", "<C-h>", function() navigate("h", "left") end,  vim.tbl_extend("force", opts, { desc = "Navigate left (nvim/herdr)" }))
  vim.keymap.set("n", "<C-j>", function() navigate("j", "down") end,  vim.tbl_extend("force", opts, { desc = "Navigate down (nvim/herdr)" }))
  vim.keymap.set("n", "<C-k>", function() navigate("k", "up") end,    vim.tbl_extend("force", opts, { desc = "Navigate up (nvim/herdr)" }))
  vim.keymap.set("n", "<C-l>", function() navigate("l", "right") end, vim.tbl_extend("force", opts, { desc = "Navigate right (nvim/herdr)" }))
  -- stylua: ignore end
end

return M
