-- opencode-tmux/prompts.lua
-- handles prompt sending, prompt picker, and free-form input

local server = require("opencode-tmux.server")
local context = require("opencode-tmux.context")

local M = {}

-- send a prompt string to opencode
-- text should already have placeholders resolved
---@param text string        Prompt text (placeholders should be resolved by this point, so it's ready to send)
---@param submit? boolean    Whether to auto-submit (by default this is just false)
function M.send(text, submit)
	server.ensure(function()
		server.append_prompt("\n" .. text, function(ok)
			if ok then
				if submit then
					server.submit_prompt()
				end
				vim.notify("OpenCode: prompt sent", vim.log.levels.INFO)
			end
		end)
	end)
end

-- show a picker with all configured prompts
-- resolves placeholders and sends the selected one
-- captures visual selection up front so it survives the vim.ui.select() callback
function M.select()
	local this_ctx = context.this()
	local config = require("opencode-tmux").config
	local items = {}
	for name, p in pairs(config.prompts) do
		table.insert(items, { name = name, prompt = p.prompt, submit = p.submit })
	end
	table.sort(items, function(a, b)
		return a.name < b.name
	end)

	vim.ui.select(items, {
		prompt = "OpenCode prompt: ",
		format_item = function(item)
			return item.name .. "  " .. item.prompt
		end,
	}, function(choice)
		if not choice then
			return
		end
		local resolved = context.resolve(choice.prompt, this_ctx)
		M.send(resolved, choice.submit)
	end)
end

-- free-form input
-- lets the user type a prompt and resolves placeholders before sending
-- captures visual selection up front so it survives the vim.ui.input() callback
---@param opts? { default?: string, submit?: boolean }
function M.ask(opts)
	opts = opts or {}
	local this_ctx = context.this()
	vim.ui.input({ prompt = "OpenCode: ", default = opts.default or "" }, function(input)
		if not input or input == "" then
			return
		end
		local resolved = context.resolve(input, this_ctx)
		M.send(resolved, opts.submit)
	end)
end

return M
