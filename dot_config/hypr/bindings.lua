-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.
--
-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- ══════════════════════════════════════════════════════════════════════════════
-- Applications — écarts par rapport aux défauts Omarchy
-- ══════════════════════════════════════════════════════════════════════════════
-- Tous les autres lanceurs (terminal, navigateur, Signal, Obsidian, 1Password,
-- ChatGPT, HEY, YouTube, WhatsApp, X…) sont déjà les défauts Omarchy et n'ont
-- pas à être répétés ici.

-- Omarchy 4 bind SUPER+SHIFT+W sur Omawrite, son éditeur Markdown maison.
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- ══════════════════════════════════════════════════════════════════════════════
-- Focus au hjkl, en plus des flèches
-- ══════════════════════════════════════════════════════════════════════════════
-- Même modèle mental que les deux autres couches : ctrl+h/j/k/l chez herdr,
-- vim-tmux-navigator dans tmux. Les flèches d'Omarchy restent en place, on
-- ajoute juste une seconde façon de faire le même geste.
--
-- Trois défauts Omarchy tombent au passage, H étant la seule des quatre touches
-- à être libre :
--   SUPER+J  Toggle window split      → plus de raccourci
--   SUPER+L  Toggle workspace layout  → plus de raccourci
--   SUPER+K  Show key bindings        → déplacé sur SUPER+SHIFT+K ci-dessous
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

local focus_directions = {
  { key = "H", direction = "l", label = "left" },
  { key = "J", direction = "d", label = "below" },
  { key = "K", direction = "u", label = "above" },
  { key = "L", direction = "r", label = "right" },
}

for _, entry in ipairs(focus_directions) do
  o.bind(
    "SUPER + " .. entry.key,
    "Focus on " .. entry.label .. " window",
    hl.dsp.focus({ direction = entry.direction })
  )
end

-- L'antisèche des raccourcis mérite de survivre à son éviction par SUPER+K.
o.bind("SUPER + SHIFT + K", "Show key bindings", "omarchy-menu-keybindings")

-- ══════════════════════════════════════════════════════════════════════════════
-- Couche i3 — supprimée
-- ══════════════════════════════════════════════════════════════════════════════
-- Ce fichier portait une reprise des raccourcis i3 sur ALT (mod+…). Elle est
-- abandonnée au profit des défauts Omarchy, qui restent sur SUPER : la liste
-- officielle compte une douzaine de gestes qui portent déjà ALT en second
-- modificateur (SUPER+ALT+F, SUPER+ALT+TAB, SUPER+ALT+chiffre, SUPER+ALT+flèche…)
-- et qui n'ont pas de traduction sur une couche ALT sans se marcher dessus.
--
-- hypr/workspaces.lua garde en revanche les workspaces indépendants par écran,
-- reposés sur les touches Omarchy.
