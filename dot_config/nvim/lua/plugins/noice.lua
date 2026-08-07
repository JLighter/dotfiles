return {
  "folke/noice.nvim",
  opts = {
    popupmenu = {
      enabled = false,
      backend = "cmp"
    },
    cmdline = {
      enabled = true, -- enables the Noice cmdline UI
      view = "cmdline", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
      opts = {}, -- global options for the cmdline. See section on views
      ---@type table<string, any>
      format = {
        cmdline = { pattern = "^:", icon = " ", lang = "vim" },
        search_down = { kind = "search", pattern = "^/", icon = "  ", lang = "regex" },
        search_up = { kind = "search", pattern = "^%?", icon = "  ", lang = "regex" },
        filter = { pattern = "^:%s*!", icon = " $", lang = "bash" },
        lua = { pattern = { "^:%s*lua%s+", " ^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = " ", lang = "lua" },
        help = { pattern = "^:%s*he?l?p?%s+", icon = " 󰋗" },
        calculator = { pattern = "^=", icon = " ", lang = "vimnormal" },
        increname = { pattern = "^:IncRename", icon = " 󱈄", lang = "viminsert" },
      },
    },
    lsp = {
      message = {
        enabled = false
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
      },
    },
    presets = {
      bottom_search = true,
      command_palette = false,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = true,
    },
  },
  -- stylua: ignore
  keys = {
    { "<leader>unl", function() require("noice").cmd("last") end, desc = "Noice Last Message" },
    { "<leader>unh", function() require("noice").cmd("history") end, desc = "Noice History" },
    { "<leader>una", function() require("noice").cmd("all") end, desc = "Noice All" },
    { "<leader>und", function() require("noice").cmd("dismiss") end, desc = "Dismiss All" },
    { "<leader>unt", function() require("noice").cmd("telescope") end, desc = "Noice Telescope" },
    { "<leader>snl" },
    { "<leader>snh" },
    { "<leader>sna" },
    { "<leader>snd" },
    { "<leader>snt" },
  },
}
