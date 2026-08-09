# Omarchy shell surfaces. Colors derive from colors.toml; sizes and the
# typographic scale come from the keys below. Themes can ship
# themes/<name>/shell.toml to replace this generated file.
#
# ─────────────────────────────────────────────────────────────────────────────
# Copie personnelle de $OMARCHY_PATH/default/themed/shell.toml.tpl. Un template
# présent ici prime sur celui d'Omarchy : après un `omarchy update`, comparer
# les deux fichiers pour récupérer les nouveautés du template amont.
#
# Écart avec l'amont : chrome sans bordure. Le shell Quickshell n'expose aucun
# token d'ombre et Hyprland 0.56 n'a pas de layer rule `shadow` — les liserés
# retirés sont donc compensés par des remplissages plus francs, pas par une
# ombre portée. Seules les fenêtres (looknfeel.lua) ont une vraie ombre.
#
# Les bordures qui portent une information d'état sont conservées : [polkit] et
# [lock] (échec d'authentification) et [image-picker] (élément sélectionné).
# ─────────────────────────────────────────────────────────────────────────────

[bar]
# Alpha companions (where present) range from 0 (invisible) to 1 (opaque).
background       = "{{ bg }}"
background-alpha = 1.0
text             = "{{ fg }}"
# Modules calling attention to themselves (recording, voxtype, alerts, updates)
active           = "{{ red }}"
# Cross-axis size at font base-size 12. size-horizontal is the height of
# top/bottom bars; size-vertical is the width of left/right bars. With
# scale-with-font enabled, these grow/shrink with [font] base-size.
scale-with-font  = true
size-horizontal  = 26
size-vertical    = 28

[hyprland]
# Shared Hyprland-derived border tokens. Surface sections reference these so
# lock, notifications, popups, and menu-style cards stay aligned with the
# current Hyprland active-border gradient.
active-border            = "{{ shell_gradient hyprland_active_border accent }}"
active-border-foreground = "{{ shell_gradient hyprland_active_border fg }}"

[controls]
# Shared state tokens for interactive control chrome (buttons, dropdowns,
# tab strips, etc).

# Normal: idle control chrome. Border widths accept one CSS-style scalar/list:
# N, "Y X", "T X B", or "T R B L". Per-side keys like
# normal-border-width-left override the list. Each *-border accepts either a
# solid color or a Hyprland-style gradient, e.g. "rgba(...) rgba(...) 45deg".
# Sans liseré, chaque état doit se lire au seul remplissage : les alphas sont
# donc plus écartés que dans le template amont, pour que idle, survol, focus
# clavier et sélection restent distinguables les uns des autres.
normal-color        = "{{ fg }}"
normal-fill-alpha   = 0.06
normal-border       = "{{ fg }}"
normal-border-width = 0
normal-border-alpha = 0.4

# Hover-cursor: mouse hover and the panel keyboard cursor.
hover-cursor-color        = "{{ fg }}"
hover-cursor-fill-alpha   = 0.12
hover-cursor-border       = "{{ fg }}"
hover-cursor-border-width = 0
hover-cursor-border-alpha = 0.25

# Focus: Qt activeFocus. Mirror the hover-cursor values by default so
# mouse hover, keyboard cursor, and tab focus all read as the same state
# — themes that want focus to stand out override these four lines.
# Ici le focus clavier est volontairement plus marqué que le survol : c'est
# le seul repère restant pour naviguer sans souris.
focus-color        = "{{ fg }}"
focus-fill-alpha   = 0.16
focus-border       = "{{ fg }}"
focus-border-width = 0
focus-border-alpha = 0.25

# Selected: persistent chosen/current state.
selected-color        = "{{ fg }}"
selected-fill-alpha   = 0.24
selected-border       = "{{ fg }}"
selected-border-width = 0
selected-border-alpha = 1.0

# Momentary fills.
pressed-fill-alpha   = 0.22
selection-fill-alpha = 0.35

[spacing]
# `scale` multiplies shared margins, gaps, padding, controls, and panel
# dimensions; components keep their proportions. With scale-with-font
# enabled, those dimensions grow/shrink with [font] base-size too. Per-token
# overrides (in px) below pin individual values without affecting the rest
# of the scale. Uncomment any to tune a specific surface.
scale = 1.0
scale-with-font = true
# xxs                       = 2
# xs                        = 3
# sm                        = 4
# md                        = 6
# lg                        = 8
# xl                        = 10
# xxl                       = 12
# xxxl                      = 14
# huge                      = 18
# control-gap               = 8
# control-padding-x         = 10
# control-padding-y         = 6
# input-padding-y           = 7
# control-height            = 28
# popup-row-height          = 28
# row-gap                   = 8
# row-padding-x             = 12
# label-gap                 = 4
# panel-gap                 = 14
# panel-padding             = 18
# popup-padding             = 14
# dropdown-width            = 240
# searchable-dropdown-width = 260
# number-field-width        = 120
# searchable-popup-min-height = 220

[font]
# base-size is the rem root for the type scale. Every Style.font.<token>
# derives from it (e.g. body = base, subtitle ≈ base * 1.083,
# heading ≈ base * 1.333). The shell only floors this at 1px; increase it
# as much as you want.
base-size = 12
# Per-token overrides, in px. Uncomment any to pin a specific size without
# affecting the rest of the scale. Useful for stylistic emphasis (a
# minimalist theme that wants a bigger heading without scaling everything).
# caption       = 10
# body-small    = 11
# body          = 12
# subtitle      = 13
# title         = 14
# heading       = 16
# display       = 24
# display-large = 28
# icon-small    = 11
# icon          = 14
# icon-large    = 18

[popups]
# Shared by every bar flyout (dropdowns, OSD, popup cards).
# Border accepts either a solid color or a Hyprland-style gradient. Border
# widths accept one CSS-style scalar/list: N, "Y X", "T X B", or "T R B L";
# individual border-width-top/right/bottom/left keys override the list.
background       = "{{ bg }}"
background-alpha = 1.0
text             = "{{ fg }}"
border           = "hyprland.active-border"
border-alpha     = 0.0
# border-width     = 2

[tooltip]
# Hover tooltips across the bar, panels, and buttons. Fond rendu opaque :
# sans liseré, la légère transparence d'origine (0.97) laissait le texte du
# fond transparaître à travers l'infobulle.
background       = "{{ bg }}"
background-alpha = 1.0
text             = "{{ fg }}"
border           = "hyprland.active-border-foreground"
border-alpha     = 0.0

[notifications]
background       = "{{ bg }}"
background-alpha = 1.0
text             = "{{ fg }}"
# Conventionally matches the Hyprland active-window border. Border accepts
# either a solid color or the full active-border gradient.
border           = "hyprland.active-border"
border-alpha     = 0.0
# border-width     = 2
countdown        = "{{ accent }}"

[launcher]
# Same six tokens as [menu], applied to the launcher overlay. Alpha
# companions go from 0 (invisible) to 1 (opaque). scrim is the full-screen
# dim layer behind the card; background is the card itself. Defaults
# mirror [menu] with the card at 0.95 to preserve the legacy translucency.
background                = "{{ bg }}"
background-alpha          = 0.95
text                      = "{{ fg }}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 0.0
scrim                     = "{{ bg }}"
scrim-alpha               = 0.5
# La ligne sélectionnée n'a plus de liseré : son fond est renforcé pour rester
# repérable pendant la navigation au clavier.
selected-background       = "{{ fg }}"
selected-background-alpha = 0.14
selected-text             = "{{ accent }}"
selected-border           = "hyprland.active-border-foreground"
selected-border-alpha     = 0.0

[menu]
# Cards, rows, and selected-row treatment. Alpha companions (where present)
# go from 0 (invisible) to 1 (opaque). scrim is the full-screen dim layer
# behind the card. Clipboard and emojis inherit these tokens.
background                = "{{ bg }}"
background-alpha          = 1.0
text                      = "{{ fg }}"
border                    = "hyprland.active-border-foreground"
border-alpha              = 0.0
scrim                     = "{{ bg }}"
scrim-alpha               = 0.5
# Ligne sélectionnée alignée sur la barre : le halo d'accent à 18 % que pose
# WidgetButton au survol, et non plus un aplat d'encre. `{{ red }}` et non
# `{{ accent }}` — c'est la teinte que [bar] active donne déjà à tout ce qui
# s'allume dans la barre, du workspace courant à la cloche de notification.
#
# Le label, lui, garde son encre : recolorer le texte *et* poser un fond faisait
# bouger deux choses pour un seul changement d'état. C'est le même parti que
# local.menu, le clone qui sert les raccourcis clavier — ces tokens habillent ce
# qu'il ne peut pas atteindre : les prompts `omarchy-menu-select` /
# `omarchy-menu-input`, dont la cible est câblée en dur, plus le presse-papiers
# et les emojis qui héritent de [menu].
selected-background       = "{{ red }}"
selected-background-alpha = 0.18
selected-text             = "{{ fg }}"
selected-border           = "hyprland.active-border-foreground"
selected-border-alpha     = 0.0

[polkit]
# Polkit authentication prompt (sudo/password dialogs). scrim is the
# darkening layer behind the card; background is the card itself.
# text-error tints the lock icon, password text, and placeholder when
# authentication fails. border-alpha applies to both border and
# border-error (the two states are mutually exclusive in time).
background       = "{{ bg }}"
background-alpha = 1.0
text             = "{{ fg }}"
text-error       = "{{ red }}"
border           = "hyprland.active-border"
border-error     = "{{ red }}"
border-alpha     = 1.0
scrim            = "{{ bg }}"
scrim-alpha      = 0.5
# accent is the lock-icon glyph color + text-selection tint.
accent           = "{{ accent }}"

[lock]
# Lock screen password input. background/background-alpha control the
# centered input field card; border/border-active/border-error cycle
# through idle, typing/authenticating, and wrong-password states.
# border-alpha applies to all three border states (they are mutually
# exclusive in time).
background       = "{{ bg }}"
background-alpha = 0.8
text             = "{{ fg }}"
placeholder      = "{{ mix fg bg 34% }}"
text-error       = "{{ red }}"
border           = "hyprland.active-border"
border-active    = "hyprland.active-border"
border-error     = "{{ red }}"
border-alpha     = 1.0
# selection is the text-selection tint inside the input field.
selection        = "{{ accent }}"
selection-alpha  = 0.45

[image-picker]
# Carousel-style picker. The picker has no card surface, so `scrim` is
# the full-screen wash. Per-slice dim overlays and text outlines on top
# of the scrim track the foundational background color directly.
# unselected-border-alpha softens carousel slices that aren't selected.
scrim                   = "{{ bg }}"
scrim-alpha             = 0.5
text                    = "{{ fg }}"
selected-border         = "{{ accent }}"
selected-border-alpha   = 1.0
unselected-border       = "{{ fg }}"
unselected-border-alpha = 0.28
