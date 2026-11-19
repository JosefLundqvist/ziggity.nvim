local M = {}

local defaults = {
  command = "ziggity",
  scale = 0.9,
  winblend = 0,
  border = "rounded",
  config_file = nil,
  on_exit = nil,
}
local settings = defaults

local function notify(message)
  vim.notify(message, vim.log.levels.WARN, { title = "ziggity.nvim" })
end

local function absolute(path, cwd)
  path = vim.fs.normalize(path, { expand_env = false })
  local drive = vim.fn.has("win32") == 1 and path:match("^%a:")
  if cwd and path:sub(1, 1) ~= "/" and not drive then
    path = vim.fs.joinpath(cwd, path)
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"), { expand_env = false })
end

local function git_root(directory)
  local ok, process = pcall(vim.system, { "git", "rev-parse", "--show-toplevel" }, {
    cwd = directory,
    text = true,
  })
  if ok then
    local result = process:wait()
    if result.code == 0 and result.stdout ~= "" then
      local root = result.stdout:gsub("\n$", "")
      return vim.fs.normalize(root, { expand_env = false })
    end
  end
end

local function file_context()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or file == "" or vim.fn.isdirectory(file) == 1 then
    return
  end

  file = vim.fs.normalize(file, { expand_env = false })
  local directory = vim.fs.dirname(file)
  while directory do
    local stat = vim.uv.fs_stat(directory)
    if stat and stat.type == "directory" then
      local root = git_root(directory)
      if root then
        local canonical = vim.fs.normalize(vim.uv.fs_realpath(directory) or directory, { expand_env = false })
        local relative = file:sub(#directory + 1):gsub("^/", "")
        local path = vim.fs.joinpath(canonical, relative)
        local prefix = root:gsub("/$", "") .. "/"
        local matches = vim.startswith(path, prefix)
        if vim.fn.has("win32") == 1 then
          matches = vim.startswith(path:lower(), prefix:lower())
        end
        return root, matches and path:sub(#prefix + 1) or nil
      end
      return
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then
      return
    end
    directory = parent
  end
end

local function global_config(cwd)
  local path = settings.config_file or vim.env.ZIGGITY_CONFIG
  if path and path ~= "" then
    return absolute(path, cwd)
  end
end

function M.setup(opts)
  local config = vim.tbl_extend("force", defaults, opts or {})
  vim.validate("command", config.command, "string")
  vim.validate("scale", config.scale, function(scale)
    return type(scale) == "number" and scale > 0 and scale <= 1
  end, "a number in (0, 1]")
  vim.validate("winblend", config.winblend, function(level)
    return type(level) == "number" and level % 1 == 0 and level >= 0 and level <= 100
  end, "an integer from 0 to 100")
  vim.validate("border", config.border, { "string", "table" })
  vim.validate("config_file", config.config_file, "string", true)
  vim.validate("on_exit", config.on_exit, "function", true)
  settings = config
end

function M.open(opts)
  local cwd = absolute((opts and opts.cwd) or vim.fn.getcwd())
  if vim.fn.isdirectory(cwd) ~= 1 then
    return notify("Directory does not exist: " .. cwd)
  end

  local executable = vim.fn.exepath(settings.command)
  if executable == "" then
    return notify("Executable not found: " .. settings.command)
  end
  if vim.fn.executable("git") ~= 1 then
    return notify("Git executable not found on PATH")
  end

  local config = global_config(cwd)
  return require("ziggity.terminal").open(executable, cwd, config, settings)
end

function M.open_current_file()
  local root = file_context()
  if not root and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
    return notify("The current file is outside a Git working tree")
  end
  return M.open({ cwd = root })
end

function M.edit_config(opts)
  local cwd = vim.fn.getcwd()
  local path = not (opts and opts.bang) and global_config(cwd)
  if not path then
    local root = git_root(cwd)
    if not root then
      return notify("The working directory is outside a Git working tree")
    end
    path = vim.fs.joinpath(root, ".ziggity.ini")
  end
  vim.cmd.edit({ args = { path }, magic = { file = false, bar = false } })
  if vim.bo.filetype == "" then
    vim.bo.filetype = "dosini"
  end
end

function M.log()
  local root = git_root(vim.fn.getcwd())
  if not root then
    return notify("The working directory is outside a Git working tree")
  end
  require("ziggity.history").open(root)
end

function M.log_current_file()
  local root, path = file_context()
  if not path then
    return notify("The current buffer is not a file inside a Git working tree")
  end
  require("ziggity.history").open(root, path)
end

return M
