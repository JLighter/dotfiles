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
-- Même modèle mental que la couche mux : ctrl+h/j/k/l chez herdr et Neovim.
-- Les flèches d'Omarchy restent en place, on
-- ajoute juste une seconde façon de faire le même geste.
--
-- Trois défauts Omarchy tombent au passage, H étant la seule des quatre touches
-- à être libre. Aucun n'est perdu, tous se replient plus bas :
--   SUPER+J  Toggle window split      → SUPER+[
--   SUPER+L  Toggle workspace layout  → SUPER+]
--   SUPER+K  Show key bindings        → SUPER+SHIFT+K
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

-- ── Relogement des trois évincés ──
-- Les crochets sont libres et voisins du hjkl. Ils vont par paire, comme les
-- deux bascules de disposition : [ découpe la fenêtre, ] change le layout du
-- workspace entier.
--
-- xkbcommon nomme ces keysyms en minuscules ; « BRACKETLEFT » ne matcherait pas,
-- même piège que le « comma » des défauts Omarchy.
o.bind("SUPER + bracketleft", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + bracketright", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- L'antisèche des raccourcis mérite de survivre à son éviction par SUPER+K.
o.bind("SUPER + SHIFT + K", "Show key bindings", "omarchy-menu-keybindings")

-- ══════════════════════════════════════════════════════════════════════════════
-- Menu — bascule sur le clone local
-- ══════════════════════════════════════════════════════════════════════════════
-- `local.menu` est le menu d'Omarchy rehabille aux couleurs de la menubar (voir
-- ~/.config/omarchy/plugins/local.menu/). Les entrees, les alias et les fichiers
-- JSONC sont ceux d'Omarchy : seul le rendu change.
--
-- Le namespace `omarchy.*` etant reserve aux plugins first-party, le clone ne
-- peut pas prendre la place de `omarchy.menu` : le bin `omarchy-menu` vise
-- toujours l'original. On rebinde donc les raccourcis un a un sur le plugin
-- local, ce qui laisse deux chemins vivants :
--   - `omarchy menu ...` tape a la main ouvre encore le menu natif ;
--   - les prompts `omarchy-menu-select` / `omarchy-menu-input` (SUPER+SHIFT+K,
--     suppression de theme, timezone…) aussi, leur cible etant en dur.
-- Ces deux-la se rattrapent par le theme, pas par le binding.

local function local_menu(route)
  return string.format([[omarchy-shell shell toggle local.menu '{"menu":"%s"}']], route)
end

-- Meme table que $OMARCHY_PATH/default/hypr/bindings/utilities.lua, a la route
-- pres : toute entree ajoutee la-bas devra etre reportee ici.
local menu_bindings = {
  { keys = "SUPER + ALT + SPACE",          description = "Omarchy menu",    route = "root" },
  { keys = "SUPER + SHIFT + code:201",     description = "Omarchy menu",    route = "root" },
  { keys = "SUPER + ESCAPE",               description = "System menu",     route = "system" },
  { keys = "SUPER + CTRL + O",             description = "Toggle menu",     route = "toggle" },
  { keys = "SUPER + CTRL + C",             description = "Capture menu",    route = "capture" },
  { keys = "SUPER + CTRL + H",             description = "Hardware menu",   route = "hardware" },
  { keys = "SUPER + CTRL + S",             description = "Share",           route = "share" },
  { keys = "SUPER + CTRL + R",             description = "Set reminder",    route = "reminder-set" },
  { keys = "SUPER + CTRL + SPACE",         description = "Background switcher", route = "background" },
  { keys = "SUPER + SHIFT + CTRL + SPACE", description = "Theme menu",      route = "theme" },
}

for _, entry in ipairs(menu_bindings) do
  hl.unbind(entry.keys)
  o.bind(entry.keys, entry.description, local_menu(entry.route))
end

-- Le bouton d'alimentation garde son `locked`, sinon il devient muet ecran
-- verrouille — c'est precisement la ou on en a besoin.
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Power menu", local_menu("system"), { locked = true })

-- Seul raccourci menu a ne pas etre un simple toggle : il coupe d'abord un
-- enregistrement en cours, et n'ouvre le menu que s'il n'y en avait pas.
hl.unbind("ALT + PRINT")
o.bind(
  "ALT + PRINT",
  "Screenrecording",
  "omarchy-capture-screenrecording --stop-recording || " .. local_menu("trigger.capture.screenrecord")
)

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
