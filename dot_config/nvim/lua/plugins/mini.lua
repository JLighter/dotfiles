return {
  {
    "echasnovski/mini.surround",
    keys = {
      { "S", "<cmd> lua MiniSurround.add('visual') <CR>", desc = "Surround visual selection", mode = "x", { silent = true, noremap = true } },
      { "yss", "ys_", desc = "Add surrounding for line", mode = "n", { silent = true, noremap = true } }
    },
    opts = {
      custom_surroundings = {
        ["("] = { output = { left = "( ", right = " )" } },
        ["["] = { output = { left = "[ ", right = " ]" } },
        ["{"] = { output = { left = "{ ", right = " }" } },
        ["<"] = { output = { left = "< ", right = " >" } },
      },
      mappings = {
        add = "S", -- Add surrounding in Normal and Visual modes
        delete = "ds", -- Delete surrounding
        find = "Sf", -- Find surrounding (to the right)
        find_left = "SF", -- Find surrounding (to the left)
        highlight = "Sh", -- Highlight surrounding
        replace = "cs", -- Replace surrounding
        update_n_lines = "gsn", -- Update `n_lines`
      },
      search_method = "cover_or_next",
    },
  },
  {
    "echasnovski/mini.align",
    config = function(_, opts)
      require("mini.align").setup(opts)
    end,
  },
}
