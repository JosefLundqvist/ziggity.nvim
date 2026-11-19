local M = {}
local api = vim.api
local sessions = {}

local function set_highlights()
  api.nvim_set_hl(0, "ZiggityFloat", { default = true, link = "NormalFloat" })
  api.nvim_set_hl(0, "ZiggityBorder", { default = true, link = "FloatBorder" })
end

local function is_visible(session)
  return api.nvim_win_is_valid(session.win) and api.nvim_win_get_buf(session.win) == session.buf
end

local function float_config(settings)
  local rows = vim.o.lines - vim.o.cmdheight
  local cols = vim.o.columns
  local width = math.max(1, math.min(cols - 2, math.floor(cols * settings.scale)))
  local height = math.max(1, math.min(rows - 2, math.floor(rows * settings.scale)))
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((rows - height - 2) / 2)),
    col = math.max(0, math.floor((cols - width - 2) / 2)),
    border = settings.border,
    style = "minimal",
  }
end

local function notify(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "ziggity.nvim" })
end

local function close(session)
  if is_visible(session) then
    local focused = api.nvim_get_current_win() == session.win
    pcall(api.nvim_win_close, session.win, true)
    if focused and api.nvim_win_is_valid(session.origin) then
      pcall(api.nvim_set_current_win, session.origin)
    end
  end
  if api.nvim_buf_is_valid(session.buf) then
    pcall(api.nvim_buf_delete, session.buf, { force = true })
  end
end

local function finish(session, code)
  sessions[session.buf] = nil
  local failed = code ~= 0 and not session.dismissed
  local details = {}
  if failed and api.nvim_buf_is_valid(session.buf) then
    for _, line in ipairs(api.nvim_buf_get_lines(session.buf, -6, -1, false)) do
      if line:find("%S") and not line:match("^%[Process exited") then
        details[#details + 1] = line
      end
    end
  end
  close(session)
  if failed then
    local message = ("Ziggity exited with status %d"):format(code)
    if #details > 0 then
      message = message .. "\n" .. table.concat(details, "\n")
    end
    notify(message)
  end
  pcall(vim.cmd.checktime)
  if session.settings.on_exit then
    local ok, err = pcall(session.settings.on_exit, code, session.cwd)
    if not ok then
      notify("Exit callback failed: " .. tostring(err))
    end
  end
end

function M.open(executable, cwd, config, settings)
  local tab = api.nvim_get_current_tabpage()
  for _, session in pairs(sessions) do
    if session.tab == tab and session.cwd == cwd and is_visible(session) then
      api.nvim_set_current_win(session.win)
      vim.cmd.startinsert()
      return session.job
    end
  end

  local session = { tab = tab, origin = api.nvim_get_current_win(), cwd = cwd, settings = settings }
  session.buf = api.nvim_create_buf(false, true)
  local ok, win = pcall(api.nvim_open_win, session.buf, true, float_config(settings))
  if not ok then
    api.nvim_buf_delete(session.buf, { force = true })
    return notify("Could not open Ziggity's floating window: " .. tostring(win))
  end
  session.win = win
  vim.wo[win].winblend = settings.winblend
  vim.wo[win].winhighlight = "Normal:ZiggityFloat,NormalFloat:ZiggityFloat,FloatBorder:ZiggityBorder"
  vim.bo[session.buf].bufhidden = "wipe"

  local started, job = pcall(vim.fn.jobstart, { executable }, {
    term = true,
    cwd = cwd,
    env = config and { ZIGGITY_CONFIG = config } or nil,
    on_exit = function(_, code)
      vim.schedule(function()
        finish(session, code)
      end)
    end,
  })
  if not started or job <= 0 then
    close(session)
    return notify("Could not start Ziggity: " .. tostring(job))
  end

  session.job = job
  sessions[session.buf] = session
  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      session.dismissed = true
    end,
  })
  vim.bo[session.buf].filetype = "ziggity"
  vim.keymap.set("n", "q", function()
    close(session)
  end, { buffer = session.buf, desc = "Close Ziggity" })
  vim.cmd.startinsert()
  return job
end

set_highlights()
local group = api.nvim_create_augroup("ZiggityTerminal", { clear = true })
api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    for _, session in pairs(sessions) do
      if is_visible(session) then
        api.nvim_win_set_config(session.win, float_config(session.settings))
      end
    end
  end,
})

return M
