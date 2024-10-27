-- plugin/launchpad.lua
local M = {}

local util = require("launchpad.util")
local Config = require("launchpad.config").Config
local RunConfig = require("launchpad.config").RunConfig

--- @type Config
local config
--- @type string
local config_file = ".launchpad.json"
local config_path = vim.fn.getcwd() .. "/" .. config_file

-- Load configs from file
function M.load_configs()
	local data = util.read_json_file(config_path)
	config = Config.from_table(data)
end

-- Save configs to file
function M.save_configs()
	util.write_json_file(config_path, config:to_table())
end

-- Add or update a config
function M.update_config(name, cmd, env, env_file, is_debug)
	M.configs[name] = {
		cmd = cmd,
		env = env or {},
		env_file = env_file,
		is_debug = is_debug or false,
	}
	M.last_used[name] = os.time()
	M.save_configs()
end

function M.create_run_config()
	local run_config = RunConfig.new()

	local on_submit = function(value)
		table.insert(config.run_configs, value)
		M.save_configs()
		vim.notify("Config '" .. value.name .. "' has been created", vim.log.levels.INFO)
	end

	run_config:create_form(on_submit)
end

function M.show_run_configs()
  local on_select = function(selected)
    selected:run()
    vim.notify("Selected: " .. selected.name, vim.log.levels.INFO)
    selected.last_used = os.time()
    M.save_configs()
  end
  local on_modify = function(modified)
    for _, run_config in ipairs(config.run_configs) do
      if run_config.id == modified.id then
        run_config.name = modified.name
        run_config.cmd = modified.cmd
        run_config.env_file = modified.env_file
        run_config.env_vars = modified.env_vars
        break
      end
    end
    M.save_configs()
  end
	config:select_run_config(on_select, on_modify)
end

function M.show_debug_configs() end

-- Modified setup function
function M.setup(opts)
	M.load_configs()
end

return M
