-- opencode-tmux
-- main plugin module
-- opens opencode in a tmux pane and talks to it over HTTP

local M = {}

M.config = {
	port = 4096,
	host = "127.0.0.1",
	split = "h", -- h = horizontal (side-by-side), v = vertical (stacked)
	size = 40, -- percent of screen for the opencode pane
	compact_context = false, -- skip code block fences to save tokens

	---@type table<string, { prompt: string, submit?: boolean }>
	prompts = {
		explain = { prompt = "Explain @this and its context", submit = true },
		review = { prompt = "Review @this for correctness and readability", submit = true },
		fix = { prompt = "Fix @diagnostics", submit = true },
		optimize = { prompt = "Optimize @this for performance and readability", submit = true },
		document = { prompt = "Add comments documenting @this", submit = true },
		implement = { prompt = "Implement @this", submit = true },
		test = { prompt = "Add tests for @this", submit = true },
		diagnostics = { prompt = "Explain @diagnostics", submit = true },
		diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
	},
}

-- public api

-- send the current line or visual selection to opencode
-- figures out what to send based on the current mode
function M.send()
	local ctx = require("opencode-tmux.context").this()
	if not ctx then
		return
	end
	require("opencode-tmux.prompts").send(ctx)
end

-- send the whole buffer with a free-form prompt
function M.send_buffer(opts)
	opts = opts or {}
	require("opencode-tmux.prompts").ask({
		default = opts.default_prompt or "Explain @buffer",
		submit = true,
	})
end

-- show a picker with all configured prompts
-- resolves @this based on the current mode automatically
function M.select_prompt()
	require("opencode-tmux.prompts").select()
end

-- free-form input that resolves placeholders before sending
-- @this resolves based on the current mode automatically
function M.ask(opts)
	require("opencode-tmux.prompts").ask(opts)
end

-- submit whatever is currently in the opencode prompt
function M.submit_prompt()
	local server = require("opencode-tmux.server")
	server.ensure(function()
		server.submit_prompt(function(ok)
			if ok then
				vim.notify("OpenCode: prompt submitted", vim.log.levels.INFO)
			end
		end)
	end)
end

-- clear the current prompt in the opencode TUI
function M.clear_prompt()
	local server = require("opencode-tmux.server")
	server.ensure(function()
		server.clear_prompt(function(ok)
			if ok then
				vim.notify("OpenCode: prompt cleared", vim.log.levels.INFO)
			end
		end)
	end)
end

-- tmux

function M.tmux_open()
	require("opencode-tmux.tmux").open()
end

function M.tmux_close()
	require("opencode-tmux.tmux").close()
end

function M.tmux_toggle()
	require("opencode-tmux.tmux").toggle()
end

-- setup

---@class OpencodeTmuxConfig
---@field port? number    Server port (default 4096)
---@field host? string    Server host (default "127.0.0.1")
---@field split? string   "h" for side-by-side, "v" for stacked (default "h")
---@field size? number    Pane size in percent (default 40)
---@field compact_context? boolean  Skip code block fences in context to save tokens (default false)
---@field prompts? table<string, { prompt: string, submit?: boolean }>

---@param config? OpencodeTmuxConfig
function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("opencode_tmux_cleanup", { clear = true }),
		callback = function()
			require("opencode-tmux.tmux").cleanup()
		end,
	})
end

return M
