# Launchpad.nvim

Launchpad is a plugin for managing run and debug configurations in Neovim.

## Run configurations

<https://github.com/user-attachments/assets/ecf29263-0f8f-429f-97b8-ab8c569b000b>

- Environment variables can be set with newline-separated KEY=VALUE pairs.
- Environment variable file also follows the same format.
- The `CMD` supports some rendering options, such as `{{file}}`.
- Configurations are sorted by the time of the last run.

## Debug configurations

<https://github.com/user-attachments/assets/86a7ade7-8b5e-40a1-9215-0739b921680a>

- You can create debug configurations by running `nvim-dap`. This plugin will
automatically detect and save the configurations.
- Tested in python and golang.

## Installation

### lazy.nvim

```lua
{
  "hongzio/launchpad.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "grapp-dev/nui-components.nvim",
    "mfussenegger/nvim-dap",
    "nvim-telescope/telescope.nvim"
  },
  opts = {},
  keys = {
    {"<leader>R", function() end, desc="+Launchpad"},
    {"<leader>RC", function() require("launchpad").create_config("run") end, desc="Create run configuration", mode = {"n"}},
    {"<leader>RR", function() require("launchpad").show_configs("run") end, desc="Run configurations", mode = {"n"}},
    {"<leader>RD", function() require("launchpad").show_configs("debug") end, desc="Debug configurations", mode = {"n"}},
  },
}
```

## Options

```lua
...
  opts = {
    save_file = ".launchpad.json",
    save_dir = "path/to/dir", -- default: vim.fn.getcwd(),
    types = { "run", "debug" },
  },
...
```
