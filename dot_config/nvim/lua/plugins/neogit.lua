return {
  "fang2hou/neogit",
  branch = "feature/snacks-integration",
  cmd = { "Neogit" },
  keys = {
    { "<leader>gs", ":Neogit <CR>", desc = "Status", mode = "n", nowait = true, silent = true },
    { "<leader>gdo", ":DiffviewOpen <CR>", desc = "Open", mode = "n", nowait = true, silent = true },
    { "<leader>gdc", ":DiffviewClose <CR>", desc = "Close", mode = "n", nowait = true, silent = true },
    { "<leader>gdf", ":DiffviewToggleFiles <CR>", desc = "Toggle files", mode = "n", nowait = true, silent = true },
    { "<leader>gdh", ":DiffviewFileHistory %<CR>", desc = "File history", mode = "n", nowait = true, silent = true },
    { "<leader>gdH", ":DiffviewFileHistory<CR>", desc = "Branch history", mode = "n", nowait = true, silent = true },
    { "<leader>gdf", ":DiffviewToggleFiles <CR>", desc = "Toggle files", mode = "n", nowait = true, silent = true },
    { "<leader>ghs", ":Git stage_hunk <CR>", desc = "Stage", mode = "v", nowait = true, silent = true },
    { "<leader>ghr", ":Git stage_hunk <CR>", desc = "Reset", mode = "v", nowait = true, silent = true },
  },
  dependencies = {
    { "nvim-lua/plenary.nvim" },
    { "sindrets/diffview.nvim" },
    -- { "folke/snacks.nvim" },
  },
  opts = {
    graph_style = "unicode",
    git_services = {
      ["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
      ["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
      ["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
      ["gitlab.web-atrio.com"] = "https://gitlab.web-atrio.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
    },
    mappings = {
      finder = {
        ["<cr>"]               = "Select",
        ["<C-l>"]              = "Select",
        ["<C-c>"]              = "Close",
        ["<esc>"]              = "Close",
        ["<c-n>"]              = "Next",
        ["<c-p>"]              = "Previous",
        ["<C-j>"]              = "Next",
        ["<C-k>"]              = "Previous",
        ["<down>"]             = "Next",
        ["<up>"]               = "Previous",
        ["<tab>"]              = "InsertCompletion",
        ["<space>"]            = "MultiselectToggleNext",
        ["<s-space>"]          = "MultiselectTogglePrevious",
        ["<c-j>"]              = "NOP",
        ["<ScrollWheelDown>"]  = "ScrollWheelDown",
        ["<ScrollWheelUp>"]    = "ScrollWheelUp",
        ["<ScrollWheelLeft>"]  = "NOP",
        ["<ScrollWheelRight>"] = "NOP",
        ["<LeftMouse>"]        = "MouseClick",
        ["<2-LeftMouse>"]      = "NOP",
      },
    },
    -- Automatically show console if a command takes more than console_timeout milliseconds
    console_timeout = 10000,
    auto_show_console = true,
    disable_insert_on_commit = true,
    signs = {
      -- { CLOSED, OPENED }
      section = { "", "" },
      item = { "", "" },
      hunk = { "", "" },
    },
    integrations = {
      -- snacks = true,
      diffview = true,
    },
  },
  config = function(_, opts)
    local neogit = require("neogit")

    neogit.setup(opts)
  end,
}
