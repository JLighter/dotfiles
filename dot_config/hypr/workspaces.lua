-- Workspaces indépendants par écran.
--
-- Chaque écran a ses propres workspaces, adressés par les mêmes touches :
-- SUPER+1..5 vise toujours l'écran qui a le focus et ne touche pas à l'autre.
-- C'est le comportement d'i3, et celui que le plugin hyprsplit apportait —
-- l'API Lua de Hyprland 0.56 le rend superflu, plus rien à compiler ni à
-- réinstaller à chaque mise à jour du compositeur.
--
-- Sous le capot les identifiants restent globaux, Hyprland n'en connaît pas
-- d'autres. Le n-ième écran reçoit la tranche (n-1)*SLOTS+1 .. n*SLOTS :
-- écran de gauche → 1..5, écran de droite → 6..10. La barre les réétiquette
-- 1..5 sur chaque écran (~/.config/omarchy/plugins/local.menubar/Workspaces.qml).

local SLOTS = 5

-- ══════════════════════════════════════════════════════════════════════════════
-- Découpage des écrans
-- ══════════════════════════════════════════════════════════════════════════════

-- Écrans de gauche à droite, puis de haut en bas. On n'ordonne pas par
-- `monitor.id` : Hyprland le réattribue au branchement, et la tranche de
-- workspaces d'un écran suivrait alors l'ordre des connexions plutôt que la
-- disposition physique.
local function ordered_monitors()
  local monitors = hl.get_monitors()

  table.sort(monitors, function(left, right)
    if left.x ~= right.x then
      return left.x < right.x
    end

    if left.y ~= right.y then
      return left.y < right.y
    end

    return left.name < right.name
  end)

  return monitors
end

-- Décalage de numérotation d'un écran : 0 pour le premier, SLOTS pour le
-- deuxième, etc. Le slot n de cet écran est donc le workspace `base + n`.
local function base_of(monitor)
  if not monitor then
    return 0
  end

  for index, candidate in ipairs(ordered_monitors()) do
    if candidate.name == monitor.name then
      return (index - 1) * SLOTS
    end
  end

  return 0
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Épinglage des workspaces
-- ══════════════════════════════════════════════════════════════════════════════

-- Sans règle, un workspace se crée sur l'écran qui a le focus au moment où on
-- l'ouvre : le workspace 8 pourrait naître à gauche, et l'appariement
-- touche → écran ne tiendrait plus.
--
-- `persistent` garde les cinq slots vivants même vides, pour que la barre ne se
-- décale pas quand on ferme le dernier client d'un workspace. `default` désigne
-- celui que l'écran affiche au démarrage.

local pinned = {}

local function pin_workspaces_to_monitors()
  -- Les règles s'empilent à chaque appel : on désactive les précédentes avant
  -- de reposer les nouvelles, sinon un rebranchement laisserait cohabiter deux
  -- affectations contradictoires pour le même workspace.
  for _, rule in ipairs(pinned) do
    rule:set_enabled(false)
  end

  pinned = {}

  for index, monitor in ipairs(ordered_monitors()) do
    for slot = 1, SLOTS do
      table.insert(
        pinned,
        hl.workspace_rule({
          workspace = tostring((index - 1) * SLOTS + slot),
          monitor = monitor.name,
          persistent = true,
          default = slot == 1,
        })
      )
    end
  end
end

pin_workspaces_to_monitors()

-- Au tout premier démarrage la configuration est lue avant que les écrans ne
-- soient sortis : `hl.get_monitors()` renvoie alors une liste vide et l'appel
-- ci-dessus ne pose rien. C'est `monitor.added` qui fait le travail.
--
-- Brancher ou débrancher un écran redécoupe les tranches : le nouvel écran
-- s'insère à sa position, et tous ceux qui sont à sa droite se décalent.
hl.on("monitor.added", pin_workspaces_to_monitors)
hl.on("monitor.removed", pin_workspaces_to_monitors)
hl.on("monitor.layout_changed", pin_workspaces_to_monitors)

-- ══════════════════════════════════════════════════════════════════════════════
-- Touches — celles d'Omarchy, dont on ne change que la cible
-- ══════════════════════════════════════════════════════════════════════════════

-- La cible dépend de l'écran qui a le focus au moment de la frappe, pas de la
-- configuration : d'où une fonction évaluée à chaque appui plutôt qu'un
-- dispatcher figé à la lecture du fichier.
local function on_focused_monitor(dispatcher_for)
  return function()
    local monitor = hl.get_active_monitor()

    if not monitor then
      return
    end

    hl.dispatch(dispatcher_for(base_of(monitor)))
  end
end

-- Omarchy bind la rangée des chiffres par keycode, pas par caractère :
-- code:10 = 1 … code:19 = 0.
local function digit_key(digit)
  return "code:" .. tostring(digit + 9)
end

for slot = 1, SLOTS do
  local key = digit_key(slot)

  -- Les défauts Omarchy visaient les identifiants globaux : on repose les mêmes
  -- touches, cette fois relatives à l'écran qui a le focus.
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + ALT + " .. key)

  o.bind(
    "SUPER + " .. key,
    "Switch to workspace " .. slot,
    on_focused_monitor(function(base)
      return hl.dsp.focus({ workspace = tostring(base + slot) })
    end)
  )

  o.bind(
    "SUPER + SHIFT + " .. key,
    "Move window to workspace " .. slot,
    on_focused_monitor(function(base)
      return hl.dsp.window.move({ workspace = tostring(base + slot) })
    end)
  )

  o.bind(
    "SUPER + SHIFT + ALT + " .. key,
    "Move window silently to workspace " .. slot,
    on_focused_monitor(function(base)
      return hl.dsp.window.move({ workspace = tostring(base + slot), follow = false })
    end)
  )
end

-- SUPER+6..0 n'ont plus de cible : avec cinq slots par écran il n'existe pas de
-- sixième. On les libère plutôt que de les laisser pointer vers les workspaces
-- globaux 6..10 — c'est-à-dire, à deux écrans, vers ceux de l'écran voisin,
-- quel que soit l'écran qui a le focus.
for digit = SLOTS + 1, 10 do
  local key = digit_key(digit)

  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + ALT + " .. key)
end

-- ── Parcours relatif ─────────────────────────────────────────────────────────
-- `e+1` saute au workspace existant suivant tous écrans confondus : il quitte
-- l'écran courant dès qu'on atteint le bout de sa tranche. `m+1` reste borné à
-- l'écran, et les workspaces persistants garantissent que les cinq slots
-- existent toujours pour qu'il ait où aller.
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
hl.unbind("SUPER + mouse_down")
hl.unbind("SUPER + mouse_up")

o.bind("SUPER + TAB", "Next workspace", hl.dsp.focus({ workspace = "m+1" }))
o.bind("SUPER + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "m-1" }))
o.bind("SUPER + mouse_down", "Scroll active workspace forward", hl.dsp.focus({ workspace = "m+1" }))
o.bind("SUPER + mouse_up", "Scroll active workspace backward", hl.dsp.focus({ workspace = "m-1" }))

-- SUPER+CTRL+TAB (« Former workspace ») reste au défaut Omarchy : c'est un
-- retour arrière sur le dernier workspace visité, et le suivre jusque sur
-- l'autre écran est le comportement attendu d'un geste « reviens où j'étais ».

-- ── D'un écran à l'autre ─────────────────────────────────────────────────────
-- Omarchy pose sur SUPER+SHIFT+ALT+flèches un « déplacer le workspace vers
-- l'écran voisin ». Le geste casse l'épinglage : le workspace 3 irait vivre sur
-- l'écran de droite, où ALT+3 ne le viserait plus, et la règle d'épinglage le
-- ramènerait au premier rebranchement. On déplace la fenêtre active à la place,
-- qui atterrit dans le slot correspondant de l'écran voisin.
local monitor_directions = {
  { key = "LEFT", direction = "l", label = "left" },
  { key = "DOWN", direction = "d", label = "down" },
  { key = "UP", direction = "u", label = "up" },
  { key = "RIGHT", direction = "r", label = "right" },
}

for _, entry in ipairs(monitor_directions) do
  hl.unbind("SUPER + SHIFT + ALT + " .. entry.key)

  o.bind(
    "SUPER + SHIFT + ALT + " .. entry.key,
    "Move window to " .. entry.label .. " monitor",
    hl.dsp.window.move({ monitor = entry.direction })
  )
end
