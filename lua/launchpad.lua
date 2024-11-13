local M = {}
local Menu = require("nui.menu")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local util = require("launchpad.util")

--- @type table<string, ConfigEntity[]>
local type_to_cfg_entities = {}

--- @type Options
local options

local function get_module(type)
	return require("launchpad.config." .. type)
end

function M.load_configs()
	local save_path = options.save_dir .. "/" .. options.save_file
	local type_to_serialized_list = util.read_json_file(save_path)
	local deserialized = {}
	for type, serialized_list in pairs(type_to_serialized_list) do
		deserialized[type] = {}
		for _, serialized in ipairs(serialized_list) do
			table.insert(deserialized[type], { id = util.uuid(), config = get_module(type).deserialize(serialized) })
		end
	end
	type_to_cfg_entities = deserialized
end

function M.save_configs()
	local save_path = options.save_dir .. "/" .. options.save_file
	local serialized = {}
	for type, entities in pairs(type_to_cfg_entities) do
		serialized[type] = {}
		for _, entity in ipairs(entities) do
			table.insert(serialized[type], entity.config:serialize())
		end
	end
	util.write_json_file(save_path, serialized)
end

local function _add_config(type, config)
	if not type_to_cfg_entities[type] then
		type_to_cfg_entities[type] = {}
	end
	table.insert(type_to_cfg_entities[type], { id = util.uuid(), config = config })
end

function M.create_config(type)
	local on_created = function(config)
		vim.notify("Created: " .. config.name, vim.log.levels.INFO)
		_add_config(type, config)
		M.save_configs()
	end
	get_module(type).create(on_created)
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
	local target_entities = type_to_cfg_entities[type]
	if not target_entities then
		vim.notify("No configs found for type: " .. type, vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, entity in ipairs(target_entities) do
		table.insert(
			items,
			Menu.item(entity.config.name, {
				entity = entity,
			})
		)
	end

	table.sort(items, function(a, b)
		return a.entity.config:sort_key() > b.entity.config:sort_key()
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
			_on_select(item.entity.config)
		end,
	})

	menu:map("n", "r", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		menu:unmount()

		item.entity.config:modify(function(config)
			_on_modify(config)
		end)
	end)

	menu:map("n", "d", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		local delete_target_idx = -1
		for idx, entity in ipairs(target_entities) do
			if entity.id == item.entity.id then
				delete_target_idx = idx
				break
			end
		end
		if delete_target_idx == -1 then
			vim.notify("Config not found", vim.log.levels.ERROR)
			return
		end
		menu:unmount()
		table.remove(target_entities, delete_target_idx)
		vim.notify("Deleted: " .. item.entity.config.name, vim.log.levels.INFO)
		M.save_configs()
	end)

	menu:map("n", "K", function()
		local curr_linenr = vim.api.nvim_win_get_cursor(menu.winid)[1]
		local item = items[curr_linenr]
		local detail = item.entity.config:detail()

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
			local type_opts = options["opts"] and options["opts"][type] or {}
			get_module(type).setup(type_opts)
		else
			vim.notify("No config found for type: " .. type, vim.log.levels.WARN)
		end
	end

	M.load_configs()
end

return M
