-- opencode-tmux/tmux.lua
-- handles opening and closing the opencode tmux pane

local M = {}

-- the pane id we created, so we only clean up what we opened
-- nil means we haven't opened anything
local owned_pane = nil

-- check if we have an opencode pane open
---@return boolean
function M.has_pane()
	return owned_pane ~= nil
end

-- kill anything still listening on our port from an older opencode process
function M.kill_stale()
	local config = require("opencode-tmux").config
	local lines = vim.fn.systemlist(("ss -tlnp 2>/dev/null | grep ':%d'"):format(config.port))
	for _, line in ipairs(lines) do
		local pid = line:match("pid=(%d+)")
		if pid then
			vim.fn.system("kill " .. pid)
			vim.fn.system("sleep 0.3")
		end
	end
end

-- clean up the pane we opened and anything still holding onto the port
-- only kills the pane if we created it, so existing opencode instances are left alone
function M.cleanup()
	if not owned_pane then
		return
	end
	if vim.env.TMUX then
		vim.fn.system("tmux kill-pane -t " .. owned_pane)
	end
	M.kill_stale()
	owned_pane = nil
end

-- open opencode in a tmux split
-- always creates a new pane, never touches existing opencode instances
function M.open()
	if not vim.env.TMUX then
		vim.notify("OpenCode: not inside a tmux session", vim.log.levels.ERROR)
		return
	end

	-- if we already have a pane open, just focus it
	if owned_pane then
		vim.fn.system("tmux select-pane -t " .. owned_pane)
		return
	end

	local config = require("opencode-tmux").config
	local port = config.port
	local size = config.size or 40
	local split_flag = config.split == "v" and "-v" or "-h"

	-- clear out anything old that is still using the port
	M.kill_stale()

	-- open a new tmux pane for opencode and capture its pane id
	local cmd = ("tmux split-window %s -l %d%% -P -F '#{pane_id}' 'opencode --port %d'"):format(split_flag, size, port)
	owned_pane = vim.trim(vim.fn.system(cmd))

	-- jump back to the neovim pane after opening it
	vim.fn.system("tmux last-pane")

	vim.notify("OpenCode: started on port " .. port, vim.log.levels.INFO)
end

-- close the opencode pane if we own it
function M.close()
	if not owned_pane then
		vim.notify("OpenCode: no pane found", vim.log.levels.WARN)
		return
	end
	vim.fn.system("tmux kill-pane -t " .. owned_pane)
	owned_pane = nil
	vim.notify("OpenCode: pane closed", vim.log.levels.INFO)
end

-- close the pane if we own one, otherwise open it
function M.toggle()
	if not vim.env.TMUX then
		vim.notify("OpenCode: not inside a tmux session", vim.log.levels.ERROR)
		return
	end
	if owned_pane then
		M.close()
	else
		M.open()
	end
end

return M
