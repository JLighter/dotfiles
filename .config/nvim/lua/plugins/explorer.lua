return {
  "folke/snacks.nvim",
  lazy = false,
  opts = {
    explorer = {
      replace_netrw = true,
      filter = {
        exclude = nil,
        ignored = true,
        hidden = true,
      },
    },
    ---@type snacks.picker.Config
    picker = {
      db = {
        -- path to the sqlite3 library
        -- If not set, it will try to load the library by name.
        -- On Windows it will download the library from the internet.
        sqlite3_path = nil, ---@type string?
      },
      layout = {
        cycle = false,
      },
      layouts = {
        buffer = {
          layout = {
            zindex = 1,
            box = "vertical",
            relative = "win",
            backdrop = false,
            height = 0,
            width = 0,
            border = "none",
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "list", border = "none" },
            { win = "input", height = 1, border = "none", title = "{title} {live} {flags}", title_pos = "center" },
          },
        },
      },
      sources = {
        explorer = {
          auto_close = true,
          layout = { preset = "buffer", preview = false },
          win = {
            list = {
              keys = {
                ["o"] = "confirm",
                ["X"] = "explore_open",
              },
            },
          },
        },
      },
    },
  },
  keys = {
    {
      "-",
      function()
        Snacks.explorer()
      end,
      desc = "Explorer Snacks",
    },
  },
}
