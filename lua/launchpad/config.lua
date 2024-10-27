local component = require("nui-components")
local util = require("launchpad.util")

local Menu = require("nui.menu")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

--- @class RunConfig
--- @field id string
--- @field name string
--- @field cmd string
--- @field env_vars table<string, string>
--- @field env_file string
--- @field last_used number
RunConfig = {}

--- @param config? RunConfig
--- @return RunConfig
function RunConfig.new(config)
	local self = {
    id = config and config.id or util.uuid(),
		name = "",
		cmd = "",
		env_vars = {},
		env_file = "",
		last_used = 0,
	}
	setmetatable(self, { __index = RunConfig })
	return self
end

function RunConfig.from_table(tbl)
	local self = RunConfig.new()
  self.id = tbl.id or util.uuid()
	self.name = tbl.name
	self.cmd = tbl.cmd
	self.env_vars = tbl.env_vars
	self.env_file = tbl.env_file
	self.last_used = tbl.last_used
	return self
end

function RunConfig:to_table()
	return {
		name = self.name,
		cmd = self.cmd,
		env_vars = self.env_vars,
		env_file = self.env_file,
		last_used = self.last_used,
	}
end

--- @param on_submit fun(value: RunConfig) @Function to call when the form is submitted
function RunConfig:create_form(on_submit)
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
					on_submit(self)
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
end

M.RunConfig = RunConfig

--- @class Config
--- @field run_configs RunConfig[]
local Config = {}

function Config.new()
	local self = {
		run_configs = {},
	}
	setmetatable(self, { __index = Config })
	return self
end

function Config.from_table(tbl)
	local self = Config.new()
	if not tbl.run_configs then
		return self
	end
	for _, run_config in ipairs(tbl.run_configs) do
		table.insert(self.run_configs, RunConfig.from_table(run_config))
	end
	return self
end

function Config:to_table()
	local tbl = {
		run_configs = {},
	}
	for _, run_config in ipairs(self.run_configs) do
		table.insert(tbl.run_configs, run_config:to_table())
	end
	return tbl
end

function Config:select_config(configs, title, on_select, on_modify)
	table.sort(configs, function(a, b)
		return a.last_used > b.last_used
	end)

	local items = {}
	for _, config in ipairs(configs) do
		table.insert(
			items,
			Menu.item(config.name, {
				config = config,
			})
		)
	end

	local menu = Menu({
		position = "50%",
		relative = "editor",
		size = {
			width = 25,
			height = 5,
		},
		border = {
			style = "single",
			text = {
				top = "[" .. title .. "]",
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	}, {
		lines = items,
		max_width = 20,
		keymap = {
			focus_next = { "j", "<Down>", "<Tab>" },
			focus_prev = { "k", "<Up>" },
			close = { "q", "<Esc>" },
			submit = { "<CR>" },
		},
		on_submit = function(item)
			on_select(item.config)
		end,
	})

  menu:map("n", "r", function()
    local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
    local item = items[curr_linenr]
    menu:unmount()

    item.config:create_form(function(value)
      on_modify(value)
    end)
  end)

	menu:map("n", "K", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]

		-- Create details popup
		local details = Popup({
			enter = false,
			focusable = false,
			border = {
				style = "rounded",
				text = {
					top = " Profile Details ",
					top_align = "center",
				},
			},
			position = {
				row = 0,
				col = 25 + 2,
			},
			size = {
				width = 60,
				height = 10,
			},
		})

		-- Set content
		local lines = {
			"Config: " .. item.text,
			"Command: " .. item.config.cmd,
			"Environment File: " .. (item.config.env_file or "None"),
			"",
			"Environment Variables:",
		}

		local has_env = false
		for k, v in pairs(item.config.env_vars or {}) do
			has_env = true
			table.insert(lines, string.format("  %s=%s", k, v))
		end
		if not has_env then
			table.insert(lines, "  None")
		end

		vim.api.nvim_buf_set_lines(details.bufnr, 0, -1, false, lines)

		-- Mount the popup
		details:mount()

		-- Close details when cursor moves
		menu:on(event.BufLeave, function()
			details:unmount()
		end)
		menu:on(event.CursorMoved, function()
			details:unmount()
		end)
	end)

	menu:mount()
end

--- @param on_select fun(config: RunConfig) @Function to call when the config is selected
--- @param on_modify fun(config: RunConfig) @Function to call when the config is modified
function Config:select_run_config(on_select, on_modify)
	self:select_config(self.run_configs, "Run configurations", on_select, on_modify)
end
M.Config = Config

return M
