-- opencode-tmux/context.lua
-- stuff for building context we send to prompts

local M = {}

-- wrap code in whatever fence style the user configured
-- returns "" when compact_context is on (no fences at all)
-- supports "backticks" (default), "xml", or a custom { open, close } table
-- the open pattern can contain %s which gets replaced with the language
---@param lang string   e.g. "lua", "diff", "python"
---@param code string   the raw code to wrap
---@return string
local function fence(lang, code)
	if require("opencode-tmux").config.compact_context then
		return ""
	end
	local cfg = require("opencode-tmux").config.code_fence or "backticks"
	local open_pat, close_pat
	if type(cfg) == "table" then
		open_pat = cfg.open or "```%s"
		close_pat = cfg.close or "```"
	elseif cfg == "xml" then
		open_pat = '<code language="%s">'
		close_pat = "</code>"
	else -- "backticks" or anything else
		open_pat = "```%s"
		close_pat = "```"
	end
	local open_str = open_pat:find("%%s") and open_pat:format(lang) or open_pat
	return ("\n%s\n%s\n%s"):format(open_str, code, close_pat)
end

-- take some lines and wrap them in a code block with file + line info
-- so we have both the snippet and where it came from
-- if compact_context is on, skip the code block fences to save tokens
---@param lines string[]
---@param filepath string
---@param start_line number  1-indexed
---@return string
function M.format(lines, filepath, start_line)
	local rel = vim.fn.fnamemodify(filepath, ":~:.")
	local ft = vim.bo.filetype or ""
	local end_line = start_line + #lines - 1
	local range
	if #lines == 1 then
		range = ("L%d"):format(start_line)
	else
		range = ("L%d-%d"):format(start_line, end_line)
	end
	local msg = ("From `%s:%s`"):format(rel, range)
	msg = msg .. fence(ft, table.concat(lines, "\n"))
	return msg
end

-- grab the current line and format it with file + line info
-- basically for the case where we just want the thing under the cursor
---@return string?
function M.current_line()
	local line = vim.api.nvim_get_current_line()
	if vim.trim(line) == "" then
		return nil
	end
	local filepath = vim.api.nvim_buf_get_name(0)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	return M.format({ line }, filepath, row)
end

-- grab the current visual selection and format it the same way
-- reads the live visual range directly so callers don't need feedkeys or defer_fn
-- exits visual mode after reading so the user lands back in normal mode
---@return string?
function M.visual_selection()
	local anchor = vim.fn.getpos("v")
	local cursor = vim.fn.getpos(".")
	local start_row = math.min(anchor[2], cursor[2])
	local end_row = math.max(anchor[2], cursor[2])
	local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
	local filepath = vim.api.nvim_buf_get_name(0)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	local all_empty = true
	for _, l in ipairs(lines) do
		if vim.trim(l) ~= "" then
			all_empty = false
			break
		end
	end
	if all_empty then
		return nil
	end
	return M.format(lines, filepath, start_row)
end

-- return the current line or visual selection depending on what mode we are in
-- so callers don't need to care about mode at all
---@return string?
function M.this()
	local mode = vim.api.nvim_get_mode().mode
	if mode == "v" or mode == "V" then
		return M.visual_selection()
	end
	return M.current_line()
end

-- grab the whole buffer and turn it into one big context block
-- useful when the prompt needs the full file instead of just a small snippet
---@return string
function M.buffer()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local filepath = vim.api.nvim_buf_get_name(0)
	return M.format(lines, filepath, 1)
end

-- turn the current buffer diagnostics into plain text
-- includes file name, line numbers, and severity
---@return string
function M.diagnostics()
	local diags = vim.diagnostic.get(0)
	if #diags == 0 then
		return "(no diagnostics)"
	end
	local filepath = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
	local parts = { ("Diagnostics for `%s`:"):format(filepath) }
	for _, d in ipairs(diags) do
		local sev = vim.diagnostic.severity[d.severity] or "?"
		table.insert(parts, ("  L%d: [%s] %s"):format(d.lnum + 1, sev, d.message))
	end
	return table.concat(parts, "\n")
end

-- get the current git diff and return it as a diff block
-- if there is no diff, or the command fails, just return a small placeholder
-- respects compact_context and code_fence settings like everything else
---@return string
function M.diff()
	local out = vim.fn.system("git diff")
	if vim.v.shell_error ~= 0 or out == "" then
		return "(no git diff)"
	end
	local trimmed = vim.trim(out)
	local fenced = fence("diff", trimmed)
	if fenced == "" then
		return trimmed
	end
	return fenced
end

-- replace @placeholders inside a prompt with their actual context
-- for example @this, @buffer, @diagnostics, or @diff
---@param text string
---@param this_ctx? string  Optional @this context if we already have it
---@return string
function M.resolve(text, this_ctx)
	local replacements = {
		["@this"] = function()
			return this_ctx or M.this()
		end,
		["@buffer"] = function()
			return M.buffer()
		end,
		["@diagnostics"] = function()
			return M.diagnostics()
		end,
		["@diff"] = function()
			return M.diff()
		end,
	}
	return (
		text:gsub("@%w+", function(match)
			local fn = replacements[match]
			if fn then
				return fn()
			end
			return match -- if we don't know the placeholder, then we just leave it for opencode to handle it
			-- We could consider handling it differently, maybe by prompting the user with a message saying unknown placeholder.
			-- If anyone reads this line, and wants to contribute, with this, then I wouldn't mind merging.
		end)
	)
end

return M
