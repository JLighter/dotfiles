-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    -- Pas de bordure : la séparation entre fenêtres passe par l'ombre portée
    -- et le dim des fenêtres inactives, réglés dans le bloc decoration.
    border_size = 0,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners.
    rounding = 14,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    dim_inactive = true,
    dim_strength = 0.10,

    -- Ombre discrète en remplacement de la bordure. Le décalage vertical
    -- suffit à décoller la fenêtre du fond sans halo visible ; l'inactive
    -- est deux fois plus légère, pour que le focus reste lisible.
    shadow = {
      enabled = true,
      range = 12,
      render_power = 3,
      offset = { 0, 2 },
      color = "rgba(0000004d)",
      color_inactive = "rgba(00000026)",
    },

    -- Le blur ne floute pas la fenêtre : il floute ce qui se trouve derrière,
    -- à travers la part de translucidité. Les opacités Omarchy restent
    -- inchangées (0.97 actif / 0.9 inactif), donc l'effet se lit surtout sur
    -- les fenêtres inactives et les popups — un rappel de profondeur, pas un
    -- verre dépoli.
    blur = {
      enabled = true,

      -- size 2 / passes 3 : un rayon court, mais assez de passes pour que le
      -- flou reste lisse. L'inverse (size élevé, 1 passe) donne un flou sale,
      -- en escalier — et un rayon long fait remonter le fond d'écran dans les
      -- fenêtres translucides, au détriment du texte.
      size = 2,
      passes = 3,

      -- Indispensable côté GPU, et prérequis de xray.
      new_optimizations = true,

      -- Les fenêtres flottantes floutent le fond d'écran plutôt que les
      -- fenêtres tuilées en dessous : moins de travail par frame, et un
      -- résultat plus calme quand une popup passe au-dessus d'un terminal.
      xray = true,

      -- Menus contextuels et tooltips flous eux aussi, par cohérence.
      -- popups_ignorealpha laisse nettes les zones trop transparentes pour
      -- que le flou y ait un sens (ombres de popup, coins arrondis).
      popups = true,
      popups_ignorealpha = 0.2,
    },
  },
})

-- Le blur ci-dessus ne touche que les fenêtres. Les surfaces layer-shell —
-- barre, menu, overlays du shell — doivent le demander une par une.
--
-- `ignore_alpha` fait tout le travail de découpe : le menu est une surface
-- plein écran, dont le voile de fond est à 0.5 et la carte à 0.92 (voir
-- `cardOpacity` dans local.menu/Menu.qml). Le seuil passe entre les deux, donc
-- seule la carte floute ce qu'elle recouvre — le reste de l'écran garde son
-- voile net, sans le flou général d'un Spotlight.
--
-- `xray = false` va à l'encontre du réglage global, et c'est voulu : sous une
-- carte de menu on veut voir flouté ce qui est réellement dessous, pas le fond
-- d'écran qu'un xray ferait remonter à travers les fenêtres.
hl.layer_rule({
  name = "blur-omarchy-menu",
  match = { namespace = "^omarchy-menu$" },
  blur = true,
  ignore_alpha = 0.6,
  xray = false,
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
