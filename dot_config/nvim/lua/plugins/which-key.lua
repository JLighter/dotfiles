return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    opts.preset = "classic"
    if LazyVim.has("noice.nvim") then
      table.insert(opts.spec, { "<leader>un", group = "noice" })
    end
    if LazyVim.has("neogit.nvim") then
      table.insert(opts.spec, { "<leader>gd", group = "diff" })
    end
  end,
}
