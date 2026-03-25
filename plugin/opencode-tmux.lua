-- plugin/opencode-tmux.lua
-- Plugin loader and command definitions

-- Define plugin commands
if vim.fn.has("nvim-0.10") == 0 then
	vim.notify("This plugin requires Neovim >= 0.10", vim.log.levels.ERROR)
	return
end
