-- Clipboard for sessions whose yanks may need to reach another machine:
-- every copy is emitted as OSC 52 (inside tmux this becomes a tmux buffer,
-- rebroadcast to every attached client, local or SSH). Paste prefers the
-- local system clipboard when one is available, so content copied in other
-- apps remains pasteable; without one, paste is an OSC 52 query that
-- tmux (or the terminal) answers.
local M = {}

local function proc_lines(pid, file)
  local ok, lines = pcall(vim.fn.readfile, "/proc/" .. pid .. "/" .. file)
  return ok and lines or {}
end

local function proc_ppid(pid)
  for _, line in ipairs(proc_lines(pid, "status")) do
    local ppid = line:match("^PPid:%s+(%d+)")
    if ppid then
      return tonumber(ppid)
    end
  end
end

local function ancestor_process_named(name)
  local pid = vim.fn.getpid()

  for _ = 1, 16 do
    local ppid = proc_ppid(pid)
    if not ppid or ppid <= 1 then
      return false
    end

    local comm = proc_lines(ppid, "comm")[1] or ""
    if comm:find(name, 1, true) then
      return true
    end

    pid = ppid
  end

  return false
end

-- Commands driving the local system clipboard, when this machine has one.
-- Wayland separates the primary selection ("*") from the clipboard ("+");
-- the macOS pasteboard has no such split, so both registers share it.
local function local_clipboard()
  if
    vim.env.WAYLAND_DISPLAY ~= nil
    and vim.fn.executable("wl-copy") == 1
    and vim.fn.executable("wl-paste") == 1
  then
    return {
      copy = function(register)
        local cmd = { "wl-copy", "--sensitive", "--type", "text/plain" }
        if register == "*" then
          cmd[#cmd + 1] = "--primary"
        end
        return cmd
      end,
      paste = function(register)
        local cmd = { "wl-paste", "--no-newline" }
        if register == "*" then
          cmd[#cmd + 1] = "--primary"
        end
        return cmd
      end,
    }
  end

  if vim.fn.executable("pbcopy") == 1 and vim.fn.executable("pbpaste") == 1 then
    return {
      copy = function()
        return { "pbcopy" }
      end,
      paste = function()
        return { "pbpaste" }
      end,
    }
  end
end

function M.setup()
  local in_tmux = vim.env.TMUX ~= nil
  local in_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
  local in_herdr = vim.env.HERDR_PANE_ID ~= nil or ancestor_process_named("herdr")

  if not (in_tmux or in_ssh or in_herdr) then
    return
  end

  local osc52 = require("vim.ui.clipboard.osc52")
  local local_cb = local_clipboard()

  local function copy(register)
    local emit = osc52.copy(register)

    return function(lines)
      if local_cb then
        vim.fn.system(local_cb.copy(register), lines)
      end

      if vim.g.omarchy_remote_clipboard_osc52 ~= false then
        emit(lines)
      end
    end
  end

  local function paste(register)
    -- An OSC 52 query blocks for 10s when nothing answers it (Ghostty denies
    -- clipboard reads, Herdr does not relay them), so it stays a last resort:
    -- read the local clipboard whenever this machine has one.
    if not local_cb then
      return osc52.paste(register)
    end

    return function()
      local lines = vim.fn.systemlist(local_cb.paste(register), "", 1)
      return vim.v.shell_error == 0 and lines or {}
    end
  end

  vim.g.clipboard = {
    name = "OmarchyRemoteClipboard",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
    cache_enabled = 0,
  }
end

return M
