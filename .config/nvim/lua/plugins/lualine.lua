return {
  "nvim-lualine/lualine.nvim",
  init = function()
    vim.g.lualine_laststatus = vim.o.laststatus
    if vim.fn.argc(-1) > 0 then
      -- set an empty statusline till lualine loads
      vim.o.statusline = " "
    else
      -- hide the statusline on the starter page
      vim.o.laststatus = 0
    end
  end,
  opts = function()
    -- PERF: we don't need this lualine require madness 🤷
    local lualine_require = require("lualine_require")
    lualine_require.require = require

    local icons = require("lazyvim.config").icons

    vim.o.laststatus = vim.g.lualine_laststatus

    local colors = {
      [""] = LazyVim.ui.fg("Special"),
      ["Normal"] = LazyVim.ui.fg("Special"),
      ["Warning"] = LazyVim.ui.fg("DiagnosticError"),
      ["InProgress"] = LazyVim.ui.fg("DiagnosticWarn"),
    }

    local copilot_section = {
      function()
        local icon = require("lazyvim.config").icons.kinds.Copilot
        local status = require("copilot.api").status.data
        return icon .. (status.message or "")
      end,
      cond = function()
        if not package.loaded["copilot"] then
          return
        end
        local ok, clients = pcall(LazyVim.lsp.get_clients, { name = "copilot", bufnr = 0 })
        if not ok then
          return false
        end
        return ok and #clients > 0
      end,
      color = function()
        if not package.loaded["copilot"] then
          return
        end
        local status = require("copilot.api").status.data
        return colors[status.status] or colors[""]
      end,
    }

    return {
      options = {
        globalstatus = true,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "starter" } },
        component_separators = { left = "|", right = "|" },
        section_separators = { left = " ", right = " " },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },

        lualine_c = {
          LazyVim.lualine.root_dir(),
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
          { "filetype", separator = "", padding = { left = 1, right = 0 } },
          { LazyVim.lualine.pretty_path() },
        },
        lualine_x = {
          -- stylua: ignore
          {
            function() return "  " .. require("dap").status() end,
            cond = function () return package.loaded["dap"] and require("dap").status() ~= "" end,
            color = LazyVim.ui.fg("Debug"),
          },
          copilot_section,
          {
            require("noice").api.statusline.mode.get,
            cond = require("noice").api.statusline.mode.has,
            color = { fg = "#ff9e64" },
          },
          {
            require("lazy.status").updates,
            cond = require("lazy.status").has_updates,
            color = LazyVim.ui.fg("Special"),
          },
          {
            "diff",
            symbols = {
              added = icons.git.added,
              modified = icons.git.modified,
              removed = icons.git.removed,
            },
            source = function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns then
                return {
                  added = gitsigns.added,
                  modified = gitsigns.changed,
                  removed = gitsigns.removed,
                }
              end
            end,
          },
        },
        lualine_y = {
          { "progress", separator = " ", padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          function()
            return " " .. os.date("%R")
          end,
        },
      },
      extensions = { "neo-tree", "lazy" },
    }
  end,
}
