-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- >>> local.menubar displays (genere, ne pas editer a la main)
hl.monitor({ output = "eDP-1", mode = "2880x1800@60.00", position = "auto", scale = omarchy_monitor_scale })
hl.monitor({ output = "DP-2", mode = "1920x1080@165.00", position = "auto", scale = omarchy_monitor_scale })
hl.monitor({ output = "DP-3", mode = "1920x1080@165.00", position = "auto", scale = omarchy_monitor_scale })
-- <<< local.menubar displays
