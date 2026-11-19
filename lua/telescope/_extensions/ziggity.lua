local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local config = require("telescope.config").values

local function repositories(opts)
  local ziggity = require("ziggity")
  local roots = ziggity.repositories()
  if #roots == 0 then
    vim.notify("No repositories in this session's history yet.", vim.log.levels.INFO, { title = "Ziggity" })
    return
  end

  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "Ziggity repositories",
    finder = finders.new_table({ results = roots }),
    sorter = config.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if entry then
          actions.close(prompt_bufnr)
          ziggity.open({ cwd = entry.value })
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = { ziggity = repositories },
})
