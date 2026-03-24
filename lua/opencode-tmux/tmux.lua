-- opencode-tmux/tmux.lua
-- handles opening and closing the opencode tmux pane

local M = {}

-- kill anything still listening on our port from an older opencode process
function M.kill_stale()
  local config = require("opencode-tmux").config
  local lines = vim.fn.systemlist(
    ("ss -tlnp 2>/dev/null | grep ':%d'"):format(config.port)
  )
  for _, line in ipairs(lines) do
    local pid = line:match("pid=(%d+)")
    if pid then
      vim.fn.system("kill " .. pid)
      vim.fn.system("sleep 0.3")
    end
  end
end

-- clean up the tmux pane and anything still holding onto the port
-- mainly used when leaving neovim
function M.cleanup()
  if not vim.env.TMUX then
    M.kill_stale()
    return
  end
  local panes = vim.fn.systemlist("tmux list-panes -F '#{pane_id}:#{pane_current_command}'")
  for _, pane in ipairs(panes) do
    if pane:match("opencode") then
      local pane_id = pane:match("^(%%[^:]+)")
      if pane_id then
        vim.fn.system("tmux kill-pane -t " .. pane_id)
      end
    end
  end
  M.kill_stale()
end

-- open opencode in a tmux split
-- if it is already open somewhere, just jump to that pane instead
function M.open()
  if not vim.env.TMUX then
    vim.notify("OpenCode: not inside a tmux session", vim.log.levels.ERROR)
    return
  end

  local config = require("opencode-tmux").config
  local port = config.port
  local size = config.size or 40
  local split_flag = config.split == "v" and "-v" or "-h"

  -- see if opencode is already running in another pane
  local panes = vim.fn.systemlist("tmux list-panes -F '#{pane_id}:#{pane_current_command}'")
  for _, pane in ipairs(panes) do
    if pane:match("opencode") then
      local pane_id = pane:match("^(%%[^:]+)")
      if pane_id then
        vim.fn.system("tmux select-pane -t " .. pane_id)
        vim.notify("OpenCode: focused existing pane", vim.log.levels.INFO)
        return
      end
    end
  end
  
  -- clear out anything old that is still using the port
  M.kill_stale()

  -- open a new tmux pane for opencode
  local cmd = ("tmux split-window %s -l %d%% 'opencode --port %d'"):format(split_flag, size, port)
  vim.fn.system(cmd)

  -- jump back to the neovim pane after opening it
  vim.fn.system("tmux last-pane")

  vim.notify("OpenCode: started on port " .. port, vim.log.levels.INFO)
end

-- close the opencode pane if we can find it
function M.close()
  if not vim.env.TMUX then return end
  local panes = vim.fn.systemlist("tmux list-panes -F '#{pane_id}:#{pane_current_command}'")
  for _, pane in ipairs(panes) do
    if pane:match("opencode") then
      local pane_id = pane:match("^(%%[^:]+)")
      if pane_id then
        vim.fn.system("tmux kill-pane -t " .. pane_id)
        vim.notify("OpenCode: pane closed", vim.log.levels.INFO)
        return
      end
    end
  end
  vim.notify("OpenCode: no pane found", vim.log.levels.WARN)
end

-- close the pane if it exists, otherwise open it
function M.toggle()
  if not vim.env.TMUX then
    vim.notify("OpenCode: not inside a tmux session", vim.log.levels.ERROR)
    return
  end
  local panes = vim.fn.systemlist("tmux list-panes -F '#{pane_id}:#{pane_current_command}'")
  for _, pane in ipairs(panes) do
    if pane:match("opencode") then
      local pane_id = pane:match("^(%%[^:]+)")
      if pane_id then
        vim.fn.system("tmux kill-pane -t " .. pane_id)
        vim.notify("OpenCode: pane closed", vim.log.levels.INFO)
        return
      end
    end
  end
  M.open()
end

return M
