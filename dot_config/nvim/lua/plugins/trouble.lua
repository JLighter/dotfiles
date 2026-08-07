return {
  -- change trouble config
  {
    "folke/trouble.nvim",
    branch = "main",
    -- opts will be merged with the parent spec
    opts = {
      use_diagnostic_signs = true,
      ---@type trouble.Window.opts
      win_config = { border = { "" } }, -- window configuration for floating windows. See |nvim_open_win()|.
      auto_fold = true,
      cycle_results = false,
      ---@type table<string, trouble.Mode>
      modes = {
        symbols = {
          win = {
            position = "right",
            size = 50
          },
        },
      },
    },
  },
}
