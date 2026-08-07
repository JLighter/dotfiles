return {
  "akinsho/bufferline.nvim",
  tag = "v4.6.0",
  keys = {
    { "<leader>bb", nil },
    { "<leader>bn", ":bnext <CR>", desc = "Go to next buffer" },
    { "<leader>bp", ":bprevious <CR>", desc = "Go to previous buffer" },
    { "<leader>bP", ":BufferLineTogglePin <CR>", desc = "Pin/Unpin buffer" },
  },
  always_show_bufferline = true,
  opts = function(_, opts)
    --@type bufferline.Options
    local override = {
      diagnostics = false,
      groups = {
        items = {
          require("bufferline.groups").builtin.pinned:with({ icon = "" }),
        },
      },
      indicator = {
        style = "none",
      },
      buffer_close_icon = "󰅖",
      modified_icon = "●",
      close_icon = "",
      left_trunc_marker = "",
      right_trunc_marker = "",
      themable = true,
      mode = "tabs",
      show_buffer_icons = false,
      separator_style = { "", "" },
      show_close_icon = true,
      always_show_bufferline = true,
      offsets = {},
      -- enforce_regular_tabs = true
    }
    opts.options = override
  end,
}
