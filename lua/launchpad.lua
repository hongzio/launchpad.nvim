local M = {}
local Menu = require("nui.menu")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local util = require("launchpad.util")

--- @type table<string, any>
local type_to_configs = {}

--- @class Options
--- @field save_file string
--- @field save_dir string
--- @field types string[]
local Options = {}

--- @type Options
local options

local function get_config(type)
	return require("launchpad.config." .. type)
end

function M.load_configs()
	local save_path = options.save_dir .. "/" .. options.save_file
	local type_to_raws = util.read_json_file(save_path)
	local deserialized = {}
	for type, raws in pairs(type_to_raws) do
		deserialized[type] = {}
		for _, raw in ipairs(raws) do
			local raw_str = vim.fn.json_encode(raw)
			table.insert(deserialized[type], get_config(type).deserialize(raw_str))
		end
	end
	type_to_configs = deserialized
end

function M.save_configs()
	local save_path = options.save_dir .. "/" .. options.save_file
	local serialized = {}
	for type, configs in pairs(type_to_configs) do
		serialized[type] = {}
		for _, config in ipairs(configs) do
			table.insert(serialized[type], config:serialize())
		end
	end
	util.write_json_file(save_path, type_to_configs)
end

local function _add_config(type, config)
	if not type_to_configs[type] then
		type_to_configs[type] = {}
	end
	table.insert(type_to_configs[type], config)
end

function M.create_config(type)
	local on_created = function(config)
		vim.notify("Created: " .. config.name, vim.log.levels.INFO)
		_add_config(type, config)
		M.save_configs()
	end
	get_config(type).create(on_created)
end

local function _on_select(config)
	vim.notify("Selected: " .. config.name, vim.log.levels.INFO)
	config:run()
	M.save_configs()
end

local function _on_modify(config)
	vim.notify("Modified: " .. config.name, vim.log.levels.INFO)
	M.save_configs()
end

function M.show_configs(type)
	local target_configs = type_to_configs[type]
	if not target_configs then
		vim.notify("No configs found for type: " .. type, vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, config in ipairs(target_configs) do
		table.insert(
			items,
			Menu.item(config.name, {
				config = config,
			})
		)
	end

	table.sort(items, function(a, b)
		return a.config:sort_key() > b.config:sort_key()
	end)

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
				top = "[" .. type .. " configurations] ",
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
			_on_select(item.config)
		end,
	})

	menu:map("n", "r", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		menu:unmount()

		item.config:modify(function(value)
			_on_modify(value)
		end)
	end)

	menu:map("n", "d", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		local target_idx = -1
		for idx, config in ipairs(target_configs) do
			if config == item.config then
				target_idx = idx
				break
			end
		end
		if target_idx == -1 then
			vim.notify("Config not found", vim.log.levels.ERROR)
			return
		end
		menu:unmount()
		table.remove(target_configs, target_idx)
		vim.notify("Deleted: " .. item.config.name, vim.log.levels.INFO)
		M.save_configs()
	end)

	menu:map("n", "K", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		local detail = item.config:detail()

		local popup = Popup({
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

		vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, detail)

		popup:mount()

		menu:on(event.BufLeave, function()
			popup:unmount()
		end)
		menu:on(event.CursorMoved, function()
			popup:unmount()
		end)
	end)

	menu:mount()
end

function M.setup(opts)
	local defaults = {
		save_file = ".launchpad.json",
		save_dir = vim.fn.getcwd(),
		types = { "run" },
	}
	options = vim.tbl_extend("force", defaults, opts or {})

	for _, type in ipairs(options.types) do
		if pcall(require, "launchpad.config." .. type) then
			get_config(type).setup()
		else
			vim.notify("No config found for type: " .. type, vim.log.levels.WARN)
		end
	end

	M.load_configs()
end

return M
