return {
  "folke/snacks.nvim",
  opts = {
    ---@type snacks.picker.Config
    picker = {
      sources = {
        files = {
          layout = "vscode",
        },
        git_files = {
          layout = "vscode",
        },
        grep = {
          layout = "ivy",
        },
        grep_buffers = {
          layout = "vscode",
        },
        grep_word = {
          layout = "ivy",
        },
      },
      layouts = {
        select = {
          layout = {
            box = "vertical",
            backdrop = false,
            row = -1,
            width = 0,
            height = 4,
            max_height = 4,
            border = "top",
            title = " {source} {live}",
            title_pos = "left",
            { win = "input", height = 1, border = "none" },
            { win = "list", border = "none", height = 3 },
          },
        },
      },
      win = {
        -- input window
        input = {
          keys = {
            ["<c-l>"] = { "confirm", mode = { "i", "n" } },
            ["<tab>"] = { "confirm", mode = { "n" } },
            ["<esc>"] = { "close", mode = { "n", "i" } },
          },
        },
      },
    },
  },
  -- stylua: ignore
  keys = {
    { "<leader>/", false },
    { "<leader>gs", false },
    { "<c-p>", LazyVim.pick("files"), desc = "Find Files (Root Dir)" },
    { "<leader><space>", LazyVim.pick("live_grep"), desc = "Grep (Root dir)" },
  },
}
