local component = require("nui-components")
local util = require("launchpad.util")

local M = {}

--- @class RunConfig
--- @field id string
--- @field name string
--- @field cmd string
--- @field env_vars table<string, string>
--- @field env_file string
--- @field last_used number
RunConfig = {}

--- @param config? table<string, any>
--- @return RunConfig
function RunConfig.new(config)
	local self = {
		id = config and config.id or util.uuid(),
		name = config and config.name or "",
		cmd = config and config.cmd or "",
		env_vars = config and config.env_vars or {},
		env_file = config and config.env_file or "",
		last_used = config and config.last_used or os.time(),
	}
	setmetatable(self, { __index = RunConfig })
	return self
end

--- @return string
function RunConfig:serialize()
	local obj = {
		name = self.name,
		cmd = self.cmd,
		env_vars = self.env_vars,
		env_file = self.env_file,
		last_used = self.last_used,
	}
	return vim.fn.json_encode(obj)
end

--- @param str string @JSON string
--- @return RunConfig @RunConfig object
function M.deserialize(str)
	local obj = vim.fn.json_decode(str)
	local config = RunConfig.new(obj)
	return config
end

function RunConfig:_form(on_submitted)
	local renderer = component.create_renderer({
		width = 80,
		height = 50,
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
					on_submitted(self)
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
				size = 1,
				autoresize = true,
				max_lines = 5,
				border_label = "CMD",
				value = self.cmd,
				validate = component.validator.min_length(1),
				on_change = function(value)
					self.cmd = value
				end,
			}),
			component.text_input({
				size = 1,
				autoresize = true,
				border_label = "Env Vars",
				value = util.stringify_env_vars(self.env_vars),
				on_change = function(value)
					pcall(function()
						self.env_vars = util.parse_env_vars(value)
					end)
				end,
				validate = function(value)
					if pcall(util.parse_env_vars, value) then
						return true
					end
					return false
				end,
			}),
			component.text_input({
				size = 1,
				autoresize = true,
				border_label = "Env File",
				value = self.env_file,
				on_change = function(value)
					self.env_file = value
				end,
			})
		)
	end

	renderer:render(body)
end

function RunConfig:modify(on_modified)
	self:_form(on_modified)
end

function RunConfig:detail()
	local lines = {
		"Config: " .. self.name,
		"Command: " .. self.cmd,
		"Environment File: " .. (self.env_file or "None"),
		"",
		"Environment Variables:",
	}

	local has_env = false
	for k, v in pairs(self.env_vars or {}) do
		has_env = true
		table.insert(lines, string.format("  %s=%s", k, v))
	end
	if not has_env then
		table.insert(lines, "  None")
	end
	return lines
end

function M.create(on_created)
	local config = RunConfig.new()
	config:_form(on_created)
end

function RunConfig:run()
	local env = vim.tbl_extend("keep", self.env_vars, util.load_env_file(self.env_file))
	local cmd = self.cmd
	for k, v in pairs(env) do
		cmd = string.format("%s=%s %s", k, v, cmd)
	end
	local bufnr = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_set_current_buf(bufnr)
	vim.fn.termopen(cmd)
	vim.api.nvim_buf_set_name(bufnr, self.name .. " - " .. tostring(os.time()))
	self.last_used = os.time()
end

function RunConfig:sort_key()
	return self.last_used
end

function M.setup() end

return M
