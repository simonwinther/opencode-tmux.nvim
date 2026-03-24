-- opencode-tmux
-- main plugin module
-- opens opencode in a tmux pane and talks to it over HTTP

local M = {}

M.config = {
  port = 4096,
  host = "127.0.0.1",
  split = "h", -- h = horizontal (side-by-side), v = vertical (stacked)
  size = 40, -- percent of screen for the opencode pane

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

-- context

function M.current_line_context()
  return require("opencode-tmux.context").current_line()
end

function M.visual_selection_context()
  return require("opencode-tmux.context").visual_selection()
end

function M.buffer_context()
  return require("opencode-tmux.context").buffer()
end

-- actions

function M.send_line()
  local ctx = require("opencode-tmux.context").current_line()
  require("opencode-tmux.prompts").send(ctx)
end

function M.send_selection()
  local ctx = require("opencode-tmux.context").visual_selection()
  require("opencode-tmux.prompts").send(ctx)
end

function M.send_buffer(opts)
  opts = opts or {}
  require("opencode-tmux.prompts").ask({
    default = opts.default_prompt or "Explain @buffer",
    submit = true,
  })
end

-- prompts

function M.send_prompt(text, submit)
  require("opencode-tmux.prompts").send(text, submit)
end

function M.select_prompt(this_ctx)
  require("opencode-tmux.prompts").select(this_ctx)
end

function M.ask(opts)
  require("opencode-tmux.prompts").ask(opts)
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
