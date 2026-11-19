if vim.g.loaded_ziggity or vim.fn.has("nvim-0.11") == 0 then
  return
end
vim.g.loaded_ziggity = true

local function command(name, action, opts)
  vim.api.nvim_create_user_command(name, function(args)
    require("ziggity")[action](args)
  end, opts)
end

command("Ziggity", "open", { desc = "Open Ziggity in the working directory" })
command("ZiggityCurrentFile", "open_current_file", { desc = "Open Ziggity in the current file's repository" })
command("ZiggityConfig", "edit_config", { bang = true, desc = "Edit Ziggity's configuration" })
command("ZiggityLog", "log", { desc = "Browse repository commits" })
command("ZiggityFilter", "log", { desc = "Browse repository commits" })
command("ZiggityFilterCurrentFile", "log_current_file", { desc = "Browse commits for the current file" })
