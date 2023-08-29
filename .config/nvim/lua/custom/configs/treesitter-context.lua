local M = {
  enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
  max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
  min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
  line_numbers = true,
  multiline_threshold = 20, -- Maximum number of lines to show for a single context
  trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
  mode = 'topline',  -- Line used to calculate context. Choices: 'cursor', 'topline'
  separator = '-',
  -- Separator between context and content. Should be a single character string, like '-'.
  -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
  zindex = 20, -- The Z-index of the context window
  on_attach = function ()
    -- Change hilight color to a gray background
    vim.cmd('hi TreesitterContextSeparator guibg=grey16 guifg=grey21')
    vim.cmd('hi TreesitterContext guibg=grey17')
    vim.cmd('hi TreesitterContextBottom guibg=grey17')
  end, -- (fun(buf: integer): boolean) return false to disable attaching
}

return M