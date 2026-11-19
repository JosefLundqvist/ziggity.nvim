# ziggity.nvim

Open the Ziggity Git interface in a floating Neovim terminal, browse commit history in splits, and switch between repositories visited during your session with Telescope. Inspired by [lazygit.nvim](https://github.com/kdheepak/lazygit.nvim).

## Requirements

- Neovim 0.11 or newer.
- `git` and `ziggity` on your `PATH`. Install the terminal application using the [official Ziggity installation guide](https://github.com/simoarpe/ziggity#installation).

## Install the Neovim plugin

Choose the section for your plugin manager. Each method installs from the GitHub repository.

### lazy.nvim

Add this spec to your plugin list.

```lua
{
  "https://github.com/JosefLundqvist/ziggity.nvim",
  cmd = {
    "Ziggity",
    "ZiggityCurrentFile",
    "ZiggityConfig",
    "ZiggityLog",
    "ZiggityFilter",
    "ZiggityFilterCurrentFile",
  },
  keys = {
    { "<leader>gg", "<cmd>Ziggity<cr>", desc = "Open Ziggity" },
  },
}
```

### vim-plug

Add the `Plug` line inside your existing `plug#begin()` and `plug#end()` block. Add the mapping after the block, restart Neovim, and run `:PlugInstall`.

```vim
Plug 'https://github.com/JosefLundqvist/ziggity.nvim'
```

```vim
nnoremap <silent> <leader>gg <Cmd>Ziggity<CR>
```

### packer.nvim

Add this declaration inside your existing `require("packer").startup(...)` function, then run `:PackerSync`.

```lua
use({
  "https://github.com/JosefLundqvist/ziggity.nvim",
  config = function()
    vim.keymap.set("n", "<leader>gg", "<cmd>Ziggity<cr>", { desc = "Open Ziggity" })
  end,
})
```

### Native Neovim packages

On Neovim 0.12 or newer, add this to `init.lua`.

```lua
vim.pack.add({ "https://github.com/JosefLundqvist/ziggity.nvim" })
vim.keymap.set("n", "<leader>gg", "<cmd>Ziggity<cr>", { desc = "Open Ziggity" })
```

On Neovim 0.11, run `:echo stdpath('data')` to find your data directory. Create `site/pack/ziggity/start` inside it, then run this in your terminal with the path filled in. Add the mapping from the example above to `init.lua` and restart Neovim.

```sh
git clone https://github.com/JosefLundqvist/ziggity.nvim "<data directory>/site/pack/ziggity/start/ziggity.nvim"
```

## Quick start

Start Neovim in a Git repository and run `:Ziggity` or press `<leader>gg` with the mapping above. Press `q` inside Ziggity to quit. If your buffer belongs to a different repository than your working directory, run `:ZiggityCurrentFile` to open that file's repository.

| Command | Action |
| --- | --- |
| `:Ziggity` | Open Ziggity in Neovim's working directory. |
| `:ZiggityCurrentFile` | Open Ziggity at the current file's Git root. |
| `:ZiggityLog` or `:ZiggityFilter` | Browse commits in the working directory's repository. |
| `:ZiggityFilterCurrentFile` | Browse commits affecting the current file, following renames. |
| `:ZiggityConfig` | Edit the configured Ziggity INI file, or the working directory's repository config. |
| `:ZiggityConfig!` | Edit `.ziggity.ini` at the working directory's Git root. |

The history commands use Git to show results in Neovim splits because Ziggity has no startup flag for these views. Press `<Enter>` on a commit to open its patch and `q` to close either split.

## Configuration

The plugin works without a `setup()` call. To customize it, pass the settings you want to change. With lazy.nvim, add an `opts` table to the plugin spec. With a startup-loaded plugin, call `require("ziggity").setup({...})` from your Neovim configuration once the plugin is available.

| Setting | Default | Purpose |
| --- | --- | --- |
| `command` | `"ziggity"` | Executable name or path. |
| `scale` | `0.9` | Fraction of the editor used for the float's width and height. |
| `winblend` | `0` | Float transparency. |
| `border` | `"rounded"` | Neovim floating-window border style or custom border. |
| `config_file` | `nil` | Path to the global Ziggity INI file. Overrides the inherited `ZIGGITY_CONFIG` for the terminal process. |
| `track_on_buf_enter` | `false` | Track repositories when entering file buffers. |
| `on_exit` | `nil` | Callback `function(code, cwd)` invoked after Ziggity exits. |

The float uses `ZiggityFloat` and `ZiggityBorder`, which link to `NormalFloat` and `FloatBorder` by default.

### Ziggity's INI settings

`:ZiggityConfig` opens `config_file` if set, then falls back to `ZIGGITY_CONFIG`, then to `.ziggity.ini` at the Git root of Neovim's working directory. Use `:ZiggityConfig!` to edit the repository file directly. Use an absolute path for a global file you want to share across repositories. Ziggity loads its defaults first, then the global file, then the repository's `.ziggity.ini`, with each layer taking precedence over earlier settings. [Ziggity configuration reference](https://github.com/simoarpe/ziggity/blob/main/docs/configuration.md)

### Edit files in the same Neovim instance

To open files in the current Neovim instance when you press `e` in Ziggity, add these lines to the INI file used by that repository. The command uses the repository to resolve relative paths, so it works even when Neovim's working directory is elsewhere.

```ini
editor_command = sh -c 'root=$(pwd -W 2>/dev/null || pwd); for file do case "$file" in /*|[A-Za-z]:*) ;; *) file="$root/$file";; esac; nvim --server "$NVIM" --remote-tab "$file" || exit; done' ziggity {{filename}}
editor_in_terminal = false
```

Make sure `nvim` is on `PATH`. On Windows, Ziggity's editor command also needs `sh` on `PATH`, such as the one from Git for Windows. Ziggity composes commit messages inside its terminal interface. [Ziggity editor configuration](https://github.com/simoarpe/ziggity/blob/main/docs/configuration.md#editor-e)

## Telescope repository picker

With Telescope installed, load the extension after Telescope and ziggity.nvim are available. For lazy.nvim, setting `lazy = false` in the ziggity.nvim spec lets you load the extension during startup.

```lua
require("telescope").load_extension("ziggity")
```

Run `:Telescope ziggity` and press `<Enter>` on a repository to launch Ziggity there. The picker uses repository history from the current Neovim session. Opening Ziggity or browsing Git history adds a repository. To also track repositories as you switch between file buffers, enable `track_on_buf_enter` in the plugin settings and load the plugin at startup.
