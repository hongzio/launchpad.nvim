local component = require("nui-components")
local util = require("launchpad.util")

local M = {}

local options = {}

--- @class RunConfig : Config
--- @field id string
--- @field cmd string
--- @field env_vars table<string, string>
--- @field env_file string
--- @field last_run_time number
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
		last_run_time = config and config.last_run_time or os.time(),
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
		last_run_time = self.last_run_time,
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

local variable_resolvers = {
	["{{file}}"] = function(_)
		return vim.fn.expand("%:p")
	end,
}

function RunConfig:_form(callback)
	local renderer = component.create_renderer({
		width = 80,
		height = 40,
	})

	-- Functions like vim.fn.expand("%:p") are not working correctly inside the form
	local resolved_variables = {}
	for var, resolver in pairs(variable_resolvers) do
		resolved_variables[var] = resolver()
	end
	local is_submitted = false

	renderer:on_unmount(function()
		if not is_submitted then
			callback(nil)
		else
			callback(self)
		end
	end)

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
					for var, resolved in pairs(resolved_variables) do
						self.cmd = string.gsub(self.cmd, var, resolved)
					end
					is_submitted = true
					renderer:close()
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
			component.paragraph({
				lines = "{{file}}: current file path",
				align = "right",
				is_focusable = false,
			}),
			component.text_input({
				size = 1,
				autoresize = true,
				max_lines = 20,
				border_label = "Env Vars (Separate by newline)",
				value = util.stringify_env_vars(self.env_vars),
				on_change = function(value)
					pcall(function()
						self.env_vars = util.parse_env_vars(value)
					end)
				end,
				validate = function(value)
					local ok, _ = pcall(util.parse_env_vars, value)
					return ok
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
	local env = self.env_vars
	local env_file = self.env_file:match("^%s*(.-)%s*$") -- trim leading/trailing whitespaces
	if self.env_file ~= nil and env_file ~= "" then
		env = vim.tbl_extend("keep", env, util.load_env_file(env_file))
	end
	local cmd = self.cmd
	local env_strs = {} -- @type string[]
	for k, v in pairs(env) do
		table.insert(env_strs, string.format("export %s=%s;", k, v))
	end
	if #env_strs > 0 then
		cmd = string.format("%s %s", table.concat(env_strs, " "), cmd)
	end

	-- close all other windows
	pcall(function()
		vim.cmd("windo close")
	end)
	local bufnr = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_name(bufnr, self.name .. " - " .. tostring(os.time()))
	vim.fn.termopen(cmd)
	self.last_run_time = os.time()
end

function RunConfig:sort_key()
	return self.last_run_time
end

function M.setup(opts)
	options = vim.tbl_extend("force", options, opts or {})
end
return M
