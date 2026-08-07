--
-- add pyright to lspconfig

local util = require("lspconfig.util")

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- Use dropdown theme for lsp_references
      keys[#keys + 1] = { "gr", "<cmd>Telescope lsp_references theme=ivy<cr>", desc = "Show references" }
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        -- pyright = {},
        bufls = {},
        cssls = {
          settings = {
            css = {
              validate = true,
              lint = {
                unknownAtRules = "ignore",
              },
            },
            scss = {
              validate = true,
              lint = {
                unknownAtRules = "ignore",
              },
            },
            less = {
              validate = true,
              lint = {
                unknownAtRules = "ignore",
              },
            },
          },
        },
        angularls = {
          root_dir = function(filename, bufnr)
            return util.root_pattern("angular.json")(filename)
              or util.root_pattern("package.json")(filename)
              or util.root_pattern("project.json")(filename)
              or util.root_pattern("nx.json")(filename)
              or util.find_git_ancestor(filename)
              or util.path.dirname(filename)
          end,
        },
      },
      diagnostics = {
        virtual_text = false,
      },
    },
  },
}
