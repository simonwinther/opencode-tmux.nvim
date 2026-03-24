-- opencode-tmux/server.lua
-- handles talking to the opencode HTTP server

local M = {}

-- build the base server URL from the current config
---@return string
function M.url()
  local config = require("opencode-tmux").config
  return ("http://%s:%d"):format(config.host, config.port)
end

-- check if the server is up by hitting the health endpoint
-- calls cb(true) if it responds with 200
---@param cb fun(alive: boolean)
function M.health_check(cb)
  vim.system(
    { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", M.url() .. "/global/health" },
    { text = true },
    function(out)
      vim.schedule(function()
        cb(out.code == 0 and vim.trim(out.stdout or "") == "200")
      end)
    end
  )
end

-- post some json to one of the opencode endpoints
-- callback gets ok=false if the request failed
---@param path string
---@param body table
---@param callback? fun(ok: boolean, err?: string)
function M.post(path, body, callback)
  local json = vim.json.encode(body)
  vim.system(
    { "curl", "-s", "-X", "POST", M.url() .. path, "-H", "Content-Type: application/json", "-d", json },
    { text = true },
    function(out)
      vim.schedule(function()
        if out.code ~= 0 then
          local msg = "HTTP request failed (is OpenCode running? Try <leader>oo)"
          vim.notify("OpenCode: " .. msg, vim.log.levels.ERROR)
          if callback then callback(false, msg) end
        else
          if callback then callback(true) end
        end
      end)
    end
  )
end

-- append text to the current prompt in the opencode TUI
---@param text string
---@param cb? fun(ok: boolean, err?: string)
function M.append_prompt(text, cb)
  M.post("/tui/append-prompt", { text = text }, cb)
end

-- submit the current prompt in the opencode TUI
---@param cb? fun(ok: boolean, err?: string)
function M.submit_prompt(cb)
  M.post("/tui/submit-prompt", {}, cb)
end

-- clear the current prompt in the opencode TUI
---@param cb? fun(ok: boolean, err?: string)
function M.clear_prompt(cb)
  M.post("/tui/clear-prompt", {}, cb)
end

-- make sure the server is running before we try to use it
-- if it is not up yet, open the tmux pane and wait for it to come online
---@param fn fun()
function M.ensure(fn)
  M.health_check(function(alive)
    if alive then
      fn()
    else
      vim.notify("OpenCode: starting server...", vim.log.levels.INFO)
      require("opencode-tmux.tmux").open()
      -- poll every 500ms for up to 10s
      local attempts = 0
      local timer = vim.uv.new_timer()
      timer:start(500, 500, function()
        attempts = attempts + 1
        vim.system(
          { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", M.url() .. "/global/health" },
          { text = true },
          function(out)
            vim.schedule(function()
              if vim.trim(out.stdout or "") == "200" then
                timer:stop()
                timer:close()
                fn()
              elseif attempts >= 20 then
                timer:stop()
                timer:close()
                vim.notify("OpenCode: server didn't start in time", vim.log.levels.ERROR)
              end
            end)
          end
        )
      end)
    end
  end)
end

return M
