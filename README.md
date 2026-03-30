# opencode-tmux

Neovim plugin that talks to [OpenCode](https://github.com/anomalyco/opencode) through a tmux pane instead of embedding a terminal.

Inspired by [opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) by Nick van Dyke. Great plugin, but it uses a Neovim terminal buffer and I couldn't stand that, so I made my own that uses tmux instead. If you want the same idea but with tmux, here you go.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim), use the latest stable release:

```lua
{
  "simonwinther/opencode-tmux.nvim",
  name = "opencode-tmux",
  version = "*", -- use latest stable release (recommended)

  keys = {
    {
      "<leader>oo",
      function()
        require("opencode-tmux").tmux_toggle()
      end,
      mode = { "n", "v" },
      desc = "Toggle OpenCode pane",
    },
    {
      "go",
      function()
        require("opencode-tmux").send()
      end,
      mode = { "n", "v" },
      desc = "Send to OpenCode",
    },
    {
      "<leader>oB",
      function()
        require("opencode-tmux").send_buffer()
      end,
      desc = "Send buffer with prompt",
    },
    {
      "<leader>op",
      function()
        require("opencode-tmux").select_prompt()
      end,
      mode = { "n", "v" },
      desc = "Pick a prompt",
    },
    {
      "<leader>oa",
      function()
        require("opencode-tmux").ask({ submit = true })
      end,
      mode = { "n", "v" },
      desc = "Ask OpenCode",
    },
    {
      "<leader>os",
      function()
        require("opencode-tmux").submit_prompt()
      end,
      desc = "Submit OpenCode prompt",
    },
    {
      "<leader>oc",
      function()
        require("opencode-tmux").clear_prompt()
      end,
      desc = "Clear OpenCode prompt",
    },
  },

  config = function()
    require("opencode-tmux").setup({
      port = 4096,
      split = "h",             -- "h" side-by-side, "v" stacked
      size = 40,               -- pane size in %
      compact_context = false, -- skip code block fences to save tokens
      code_fence = "backticks", -- "backticks", "xml", or { open, close }
    })
  end,
}
```

If you want to hack on it locally, clone the repo and point lazy to it:

```lua
{
  dir = "~/dev/opencode-tmux",
  -- same config as above
}
```

## What it does

`<leader>oo` opens OpenCode in a tmux split with `--port 4096`. Everything else talks to it over HTTP.

`go` appends the current line (or visual selection) to the OpenCode prompt with file path and line numbers. You can hit `go` on multiple lines to build up context before submitting from OpenCode.

`<leader>op` opens a prompt picker (explain, review, fix, optimize, etc.). Placeholders like `@this`, `@buffer`, `@diagnostics`, `@diff` get resolved to actual editor content before sending.

`<leader>oB` sends the whole buffer with a free-form prompt. `<leader>oa` is a blank free-form input.

`<leader>os` submits whatever is currently in the OpenCode prompt. Handy when you've built up context with `go` and want to fire it off without switching panes.

`<leader>oc` clears the current OpenCode prompt without submitting it. Useful when you've built up context with `go` and want to start over. 

Set `compact_context = true` in setup to skip code block fences when sending context. Same file + line header, just without the `` ```lang `` wrapper. Saves tokens on the input side.

`code_fence` controls how code blocks are wrapped when sending context. Defaults to `"backticks"` (standard markdown triple backticks). Set it to `"xml"` for XML-style tags, or pass a table with your own `open` and `close` patterns. Use `%s` in the open pattern where the language should go.

```lua
-- xml tags: <code language="lua">...</code>
code_fence = "xml"

-- custom format: use %s for the language identifier
code_fence = { open = "<source lang=%s>", close = "</source>" }
```

Some models respond better to XML fencing than markdown backticks. If you're working with a model that prefers a different format, this lets you match it without changing anything else.

When you quit Neovim, the OpenCode pane and process get cleaned up automatically.

## Placeholders

`@this` -- current line or visual selection
`@buffer` -- entire buffer
`@diagnostics` -- LSP diagnostics for the current buffer
`@diff` -- `git diff` output

These are resolved client-side before sending to OpenCode.

## Built-in prompts

explain, review, fix, optimize, document, implement, test, diagnostics, diff.

Add your own in setup:

```lua
oc.setup({
  prompts = {
    refactor = { prompt = "Refactor @this for clarity", submit = true },
  },
})
```

## Requirements

- Neovim 0.10+
- tmux
- [OpenCode](https://github.com/anomalyco/opencode) CLI
- curl

## License

MIT
