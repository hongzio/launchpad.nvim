--- @class DebugClass
--- @field id string
--- @field name string
--- @field config table<string, string>
--- @field opts table<string, string>
--- @field last_used number
DebugConfig = {}

local M = {}

function M.setup()
	local dap = require("dap")
	dap.listeners.on_config["dummy"] = function(dap_config)
		vim.notify(vim.inspect(dap_config), vim.log.levels.INFO)
		return dap_config
	end
end
return M
