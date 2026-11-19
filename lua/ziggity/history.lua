local M = {}

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function open_buffer(kind, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, ("ziggity://%s/%d"):format(kind, buf))
  vim.bo[buf].bufhidden = "wipe"
  set_lines(buf, lines)
  vim.api.nvim_open_win(buf, true, { split = "below" })
  vim.keymap.set("n", "q", function()
    if #vim.api.nvim_list_wins() == 1 then
      vim.api.nvim_buf_delete(buf, {})
    else
      vim.cmd.close()
    end
  end, { buffer = buf, desc = "Close Ziggity history window" })
  return buf
end

local function run_git(root, buf, args, on_exit)
  local command = { "git", "--no-pager", "--literal-pathspecs" }
  vim.list_extend(command, args)
  local started, err = pcall(vim.system, command, { cwd = root, text = true }, vim.schedule_wrap(function(result)
    if vim.api.nvim_buf_is_valid(buf) then
      on_exit(result)
    end
  end))
  if not started then
    set_lines(buf, { "Could not start Git", tostring(err) })
  end
end

local function output_lines(output)
  return vim.split((output or ""):gsub("\n$", ""), "\n", { plain = true })
end

local function show_error(buf, message, result)
  set_lines(buf, vim.list_extend({ message }, output_lines(result.stderr)))
end

local function show_commit(root, commit)
  local buf = open_buffer("commit", { "Loading commit…" })
  run_git(root, buf, {
    "show", "--format=fuller", "--encoding=UTF-8", "--no-color", "--no-notes", "--no-show-signature",
    "--no-ext-diff", "--no-textconv", "--diff-merges=first-parent", "--root", "--patch", commit, "--",
  }, function(result)
    if result.code ~= 0 then
      show_error(buf, "Could not load commit", result)
      return
    end
    set_lines(buf, output_lines(result.stdout))
    vim.bo[buf].filetype = "git"
  end)
end

function M.open(root, path)
  local buf = open_buffer("history", { "Loading Git history…" })
  local args = {
    "log", "--no-color", "--no-notes", "--no-decorate", "--no-show-signature", "--encoding=UTF-8",
    "--format=%H%x09%h  %as  %s",
  }
  if path then
    vim.list_extend(args, { "--follow", "--", path })
  end

  run_git(root, buf, args, function(result)
    if result.code ~= 0 then
      run_git(root, buf, { "rev-parse", "--verify", "--quiet", "HEAD" }, function(head)
        if head.code == 1 then
          set_lines(buf, { "This repository has no commits yet." })
        else
          show_error(buf, "Could not load Git history", result)
        end
      end)
      return
    end

    local lines = {
      "Git history" .. (path and (" for " .. path:gsub("%c", " ")) or ""),
      "Enter opens a commit. q closes this window.",
      "",
    }
    local commits = {}
    for _, line in ipairs(output_lines(result.stdout)) do
      local commit, description = line:match("^(%x+)\t(.*)$")
      if commit then
        lines[#lines + 1] = description:gsub("%c", " ")
        commits[#lines] = commit
      end
    end
    if not next(commits) then
      set_lines(buf, { "No matching commits." })
      return
    end

    set_lines(buf, lines)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_set_cursor(win, { 4, 0 })
    end
    vim.keymap.set("n", "<CR>", function()
      local commit = commits[vim.api.nvim_win_get_cursor(0)[1]]
      if commit then
        show_commit(root, commit)
      end
    end, { buffer = buf, desc = "Show Git commit patch" })
  end)
end

return M
