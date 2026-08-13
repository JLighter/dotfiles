-- <C-h/j/k/l> traverse les splits Neovim, puis franchit le bord vers le pane
-- voisin du multiplexeur qui entoure la session.
--
-- Côté herdr, `~/.config/herdr/config.toml` bind les mêmes touches sur le
-- plugin vim-herdr-navigation. Celui-ci inspecte le process au premier plan du
-- pane focalisé : si c'est (n)vim, il lui réinjecte la touche au lieu de
-- déplacer le focus. Ce fichier est l'autre moitié de l'aller-retour — sans
-- lui, la touche s'arrête au bord de la disposition Neovim.
--
-- Côté tmux, nvim-tmux-navigation fait déjà les deux moitiés (et connaît les
-- panes zoomés) : on lui délègue le mouvement entier.
--
-- Le nom du fichier reste `tmux.lua` bien qu'il couvre les deux muxs : chezmoi
-- ne supprime pas la cible d'un fichier source renommé, un `mux.lua` laisserait
-- un `tmux.lua` orphelin — et ses anciens mappings — dans ~/.config/nvim.

local function in_herdr()
  return vim.env.HERDR_PANE_ID ~= nil and vim.env.HERDR_PANE_ID ~= ""
end

local function in_tmux()
  return vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
end

-- Moitié Neovim de vim-herdr-navigation : bouger dans Neovim, et uniquement si
-- la fenêtre n'a pas changé (donc on était déjà au bord), passer la main à herdr.
local function herdr_navigate(wincmd, direction)
  local previous = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)

  if vim.api.nvim_get_current_win() ~= previous then
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

local function tmux_navigate(suffix)
  require("nvim-tmux-navigation")["NvimTmuxNavigate" .. suffix]()
end

-- Reçoit la direction sous ses trois formes : `wincmd` ("h"), le nom attendu par
-- `herdr pane focus --direction` ("left"), et le suffixe de nvim-tmux-navigation
-- ("Left").
local function navigate(wincmd, herdr_direction, tmux_suffix)
  -- tmux d'abord : lancé dans un pane herdr, il hérite de HERDR_PANE_ID, et les
  -- deux tests seraient vrais. C'est alors le mux le plus proche de Neovim qui
  -- doit gagner, sans quoi le bord d'un split sauterait par-dessus ses panes.
  if in_tmux() then
    return tmux_navigate(tmux_suffix)
  end

  if in_herdr() then
    return herdr_navigate(wincmd, herdr_direction)
  end

  -- Hors mux, nvim-tmux-navigation se réduit de lui-même à un `wincmd` : il lit
  -- $TMUX au chargement et n'appelle tmux que s'il y est.
  tmux_navigate(tmux_suffix)
end

return {
  "alexghergh/nvim-tmux-navigation",
  keys = {
    -- stylua: ignore start
    { "<C-h>", function() navigate("h", "left", "Left") end,   mode = "n", desc = "Navigate left (nvim/mux)",  nowait = true, silent = true, noremap = true },
    { "<C-j>", function() navigate("j", "down", "Down") end,   mode = "n", desc = "Navigate down (nvim/mux)",  nowait = true, silent = true, noremap = true },
    { "<C-k>", function() navigate("k", "up", "Up") end,       mode = "n", desc = "Navigate up (nvim/mux)",    nowait = true, silent = true, noremap = true },
    { "<C-l>", function() navigate("l", "right", "Right") end, mode = "n", desc = "Navigate right (nvim/mux)", nowait = true, silent = true, noremap = true },
    -- stylua: ignore end
  },
  opts = {
    -- `disable_when_zoomed`, pas `disabled_when_zoomed` : le plugin lit la
    -- première orthographe, la seconde était silencieusement ignorée.
    disable_when_zoomed = true,
  },
  config = function(_, opts)
    require("nvim-tmux-navigation").setup(opts)
  end,
}
