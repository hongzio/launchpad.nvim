local M = {}
local component = require("nui-components")
local util = require("launchpad.util")

--- @type table<string, ConfigEntity[]>
local type_to_cfg_entities = {}

--- @type Options
local options = {
	save_file = ".launchpad.json",
	save_dir = vim.fn.getcwd(),
	types = { "run", "debug" },
}

local function get_module(type)
	return require("launchpad.config." .. type)
end

function M.setup(opts)
	options = vim.tbl_extend("force", options, opts or {})

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

local function add_config(type, config)
	if not type_to_cfg_entities[type] then
		type_to_cfg_entities[type] = {}
	end
	table.insert(type_to_cfg_entities[type], { id = util.uuid(), config = config })
end

function M.create_config(type)
	local function on_created(config)
		vim.notify("Created: " .. config.name, vim.log.levels.INFO)
		add_config(type, config)
		M.save_configs()
	end
	vim.schedule(function()
		get_module(type).create(on_created)
	end)
end

local function update_entity(entity)
	for _, entities in pairs(type_to_cfg_entities) do
		for _, e in ipairs(entities) do
			if e.id == entity.id then
				e.config = entity.config
				break
			end
		end
	end
end

local function on_select(entity)
	vim.notify("Selected: " .. entity.config.name, vim.log.levels.INFO)
	vim.schedule(function()
		entity.config:run()
		update_entity(entity)
		M.save_configs()
	end)
end

function M.show_configs(type)
	local entities = type_to_cfg_entities[type]
	if not entities or #entities == 0 then
		vim.notify("No configs found for type: " .. type, vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, entity in ipairs(entities) do
		table.insert(items, component.option(entity.config.name, entity))
	end

	table.sort(items, function(a, b)
		return a.config:sort_key() > b.config:sort_key()
	end)

	local renderer = component.create_renderer({
		width = 80,
		height = 40,
	})

	local selected_signal = component.create_signal({
		selected = items[1],
	})

	local detail_buf = vim.api.nvim_create_buf(false, true)
	local detail = items[1].config:detail()
	vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, detail)

	local scroll_detail_buf = function(direction)
		local winid = renderer:get_component_by_id("detail").winid
		local input = direction < 0 and [[]] or [[]]
		local count = math.abs(direction)

		vim.api.nvim_win_call(winid, function()
			vim.cmd([[normal! ]] .. count .. input)
		end)
	end

	local body = function()
		return component.columns(component.rows(
			component.select({
				flex = 2,
				autofocus = true,
				border_label = "Select a " .. type .. " configuration",
				data = items,
				selected = selected_signal.selected,
				multiselect = false,
				on_select = function(entity)
					on_select(entity)
					renderer:close()
				end,
				on_change = function(entity)
					selected_signal.selected = entity
					vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, entity.config:detail())
				end,
			}),
			component.paragraph({
				lines = "<d>: Delete an item. <r>: Modify an item. <Esc> or <q>: Close the menu.",
				align = "right",
				is_focusable = false,
			}),
			component.buffer({
				id = "detail",
				flex = 1,
				buf = detail_buf,
				border_label = "Detail",
				is_focusable = false,
			}),
			component.paragraph({
				lines = "<C-d>: Scroll down. <C-u>: Scroll up.",
				align = "right",
				is_focusable = false,
			})
		))
	end
	renderer:add_mappings({
		{
			mode = { "n", "v" },
			key = "q",
			handler = function()
				renderer:close()
			end,
		},
		{
			mode = { "n", "v" },
			key = "<C-d>",
			handler = function()
				scroll_detail_buf(1)
			end,
		},
		{
			mode = { "n", "v" },
			key = "<C-u>",
			handler = function()
				scroll_detail_buf(-1)
			end,
		},
		{
			mode = { "n", "v" },
			key = "d",
			handler = function()
				local target_entity = selected_signal.selected:get_value()
				local delete_target_idx = -1
				for idx, entity in ipairs(entities) do
					if entity.id == target_entity.id then
						delete_target_idx = idx
						break
					end
				end
				if delete_target_idx == -1 then
					vim.notify("Config not found", vim.log.levels.ERROR)
					return
				end
				table.remove(entities, delete_target_idx)
				vim.notify("Deleted: " .. target_entity.config.name, vim.log.levels.INFO)
				renderer:close()
				M.show_configs(type)
				M.save_configs()
			end,
		},
		{
			mode = { "n", "v" },
			key = "r",
			handler = function()
				renderer:close()
				local entity = selected_signal.selected:get_value()
				entity.config:modify(function(config)
					if config == nil then
						M.show_configs(type)
						return
					end
					entity.config = config
					update_entity(entity)
					M.show_configs(type)
					vim.notify("Modified: " .. entity.config.name, vim.log.levels.INFO)
					M.save_configs()
				end)
			end,
		},
	})
	renderer:render(body)
end

return M
