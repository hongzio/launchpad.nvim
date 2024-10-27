# Install

```lua
return {
  "hongzio/launchpad.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "grapp-dev/nui-components.nvim"
  },
  opts = {},
  keys = {
    {"<leader>R", function() end, desc="+Launchpad"},
    {"<leader>RC", function() require("launchpad").create_run_config() end, desc="Create run configuration", mode = {"n"}},
    {"<leader>RR", function() require("launchpad").show_run_configs() end, desc="Run configurations", mode = {"n"}},
    {"<leader>RD", function() require("launchpad").show_debug_configs() end, desc="Debug configurations", mode = {"n"}},
  },
}
```
