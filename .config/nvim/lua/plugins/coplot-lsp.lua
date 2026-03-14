return {
  {
    "copilotlsp-nvim/copilot-lsp",
    init = function()
      vim.g.copilot_nes_debounce = 300
      vim.lsp.enable("copilot_ls")
      vim.keymap.set("n", "<C-m>", function()
        if vim.b[vim.api.nvim_get_current_buf()].nes_state then
          require("copilot-lsp.nes").request_nes()
          require("copilot-lsp.nes").walk_cursor_end_edit()
        end
      end, { desc = "Copilot ask for next suggestion" })
      vim.keymap.set("n", "<C-l>", function()
        if vim.b[vim.api.nvim_get_current_buf()].nes_state then
          require("copilot-lsp.nes").apply_pending_nes()
          require("copilot-lsp.nes").walk_cursor_end_edit()
        end
      end, { desc = "Copilot apply next suggestion" })
    end,
  },
}
