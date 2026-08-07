return {
  "smjonas/inc-rename.nvim",
  cmd = "IncRename",
  opts = {
    cmd_name = "IncRename",
    hl_group = "Substitute",
    preview_empty_name = false,
    show_message = true,
    -- whether to save the "IncRename" command in the commandline history (set to false to prevent issues with
    -- navigating to older entries that may arise due to the behavior of command preview)
    save_in_cmdline_history = false,
  },
  setup = function(opts, _)
    require('inc_rename').setup(opts);
  end,

}
