local component = require("nui-components")
local util = require("launchpad.util")
--- @class DebugConfig : Config
--- @field name string
--- @field dap_config any
--- @field last_run_time number
DebugConfig = {}

--- @param obj { name: string, dap_config: dap.Configuration }
--- @return DebugConfig
function DebugConfig.new(obj)
	local self = setmetatable({}, { __index = DebugConfig })
	self.name = obj.name
	self.dap_config = obj.dap_config
	self.last_run_time = os.time()
	return self
end

function DebugConfig:serialize()
	local ret = vim.fn.json_encode({
		name = self.name,
		dap_config = self.dap_config,
		last_run_time = self.last_run_time,
	})
	return ret
end

--- @param on_modified fun(config: Config): nil
function DebugConfig:modify(on_modified)
	local renderer = component.create_renderer({
		width = 80,
		height = 40,
	})

	local body = function()
		return component.form(
			{
				id = "form",
				submit_key = "<C-s>",
				on_submit = function(is_valid)
					if not is_valid then
						vim.notify("Invalid form", vim.log.levels.ERROR)
						return
					end
					renderer:close()
					on_modified(self)
				end,
			},
			component.text_input({
				autofocus = true,
				autoresize = false,
				size = 1,
				border_label = "Name",
				value = self.name,
				validate = component.validator.min_length(1),
				on_change = function(value)
					self.name = value
				end,
			}),
			component.text_input({
				size = 15,
				autoresize = true,
				border_label = "Config",
				value = util.beautify_json(vim.fn.json_encode(self.dap_config)),
				validate = function(value)
					local ok, decoded = pcall(vim.fn.json_decode, value)
					if not ok then
						return false
					end
					self.dap_config = decoded
					return ok
				end,
			}),
			component.paragraph({
				lines = "Use <Tab> and <S-Tab> to navigate fields, <C-s> to save",
				align = "right",
				is_focusable = false,
			})
		)
	end

	renderer:render(body)
end

function DebugConfig:sort_key()
	return self.last_run_time
end

function DebugConfig:detail()
	local config_str = vim.inspect(self.dap_config)
	local config_strs = vim.split(config_str, "\n")
	local lines = {
		"Name: " .. self.name,
		"Config: ",
	}
	for _, v in ipairs(config_strs) do
		table.insert(lines, v)
	end

	return lines
end

local is_debug_config_running = false
function DebugConfig:run()
	self.last_run_time = os.time()
	is_debug_config_running = true
	require("dap").run(self.dap_config)
end

-- https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt#L309
local variable_resolvers = {
	["${file}"] = function(_)
		return vim.fn.expand("%:p")
	end,
	["${fileBasename}"] = function(_)
		return vim.fn.expand("%:t")
	end,
	["${fileBasenameNoExtension}"] = function(_)
		return vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")
	end,
	["${fileDirname}"] = function(_)
		return vim.fn.expand("%:p:h")
	end,
	["${fileExtname}"] = function(_)
		return vim.fn.expand("%:e")
	end,
	["${relativeFile}"] = function(_)
		return vim.fn.expand("%:.")
	end,
	["${relativeFileDirname}"] = function(_)
		return vim.fn.fnamemodify(vim.fn.expand("%:.:h"), ":r")
	end,
	["${workspaceFolder}"] = function(_)
		return vim.fn.getcwd()
	end,
	["${workspaceFolderBasename}"] = function(_)
		return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	end,
	["${env:([%w_]+)}"] = function(match)
		return os.getenv(match) or ""
	end,
}

local new_debug_config = nil

local options = {}

--- @type Module
local M = {
	setup = function(opts)
		options = vim.tbl_extend("force", options, opts)
		local ok, dap = pcall(require, "dap")
		if not ok then
			vim.notify("nvim-dap not found", vim.log.levels.ERROR)
			return
		end
		dap.listeners.on_config["launchpad"] = function(dap_config)
			if is_debug_config_running then
				is_debug_config_running = false
				return dap_config
			end
			local sanitized_config = vim.deepcopy(dap_config)
			for k, v in pairs(dap_config) do
				if type(v) == "function" then
					sanitized_config[k] = v()
				end
			end
			for k, v in pairs(sanitized_config) do
				if type(v) == "string" then
					for var, resolver in pairs(variable_resolvers) do
						sanitized_config[k] = string.gsub(sanitized_config[k], var, resolver)
					end
				end
			end

			local buf_path = vim.api.nvim_buf_get_name(0)
			local file_name = vim.fn.fnamemodify(buf_path, ":t")
			new_debug_config = DebugConfig.new({ name = file_name, dap_config = sanitized_config })
			require("launchpad").create_config("debug")
			return sanitized_config
		end
	end,
	deserialize = function(str)
		return DebugConfig.new(vim.fn.json_decode(str))
	end,
	create = function(on_created)
		if new_debug_config then
			on_created(new_debug_config)
			new_debug_config = nil
		else
			vim.notify("No debug config found", vim.log.levels.ERROR)
		end
	end,
}
return M
