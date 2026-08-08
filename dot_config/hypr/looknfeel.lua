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
  },
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
