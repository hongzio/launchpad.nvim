local M = {}
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

--- @param config Config
--- @return ConfigEntity
local function create_entity(config)
	return { id = util.uuid(), config = config, hash = config:hash_key() }
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
			table.insert(deserialized[type], create_entity(get_module(type).deserialize(serialized)))
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
	table.insert(type_to_cfg_entities[type], create_entity(config))
end

local function is_duplicated(type, config)
	local new_config_hash = config:hash_key()
	local entities = type_to_cfg_entities[type]
	if entities then
		for _, entity in pairs(entities) do
			if entity.config:hash_key() == new_config_hash then
				return true
			end
		end
	end
	return false
end

function M.create_config(type)
	--- @param config Config
	local function on_created(config)
		if is_duplicated(type, config) then
			vim.notify("Config already exists", vim.log.levels.INFO)
			return
		end
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

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local themes = require("telescope.themes")
local sorters = require("telescope.sorters")

function M.show_configs(type)
	local entities = type_to_cfg_entities[type]
	if not entities or #entities == 0 then
		vim.notify("No configs found for type: " .. type, vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, entity in ipairs(entities) do
		table.insert(items, {
			display = entity.config.name,
			value = entity,
			ordinal = entity.config.name,
		})
	end

	table.sort(items, function(a, b)
		return a.value.config:sort_key() > b.value.config:sort_key()
	end)

	local opts = themes.get_dropdown({})

	pickers
		.new(opts, {
			initial_mode = "normal",
			prompt_title = "Select a " .. type .. " configuration",
			preview_title = "<d> delete, <r> modify",
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					vim.api.nvim_set_option_value("wrap", true, { win = self.state.winid })
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, entry.value.config:detail())
				end,
			}),
			sorter = sorters.fuzzy_with_index_bias(),
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry.value,
						display = entry.display,
						ordinal = entry.ordinal,
					}
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				local on_select = function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					vim.notify("Selected: " .. selection.value.config.name, vim.log.levels.INFO)
					vim.schedule(function()
						selection.value.config:run()
						update_entity(selection.value)
						M.save_configs()
					end)
				end

				local on_delete = function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					local delete_target_idx = -1
					for idx, entity in ipairs(entities) do
						if entity.id == selection.value.id then
							delete_target_idx = idx
							break
						end
					end
					if delete_target_idx == -1 then
						vim.notify("Config not found", vim.log.levels.ERROR)
						return
					end
					table.remove(entities, delete_target_idx)
					vim.notify("Deleted: " .. selection.value.config.name, vim.log.levels.INFO)
					M.show_configs(type)
					M.save_configs()
				end

				local on_modify = function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					selection.value.config:modify(function(config)
						if config == nil then
							M.show_configs(type)
							return
						end
						selection.value.config = config
						update_entity(selection.value)
						M.show_configs(type)
						vim.notify("Modified: " .. selection.value.config.name, vim.log.levels.INFO)
						M.save_configs()
					end)
				end

				map("n", "d", on_delete)
				map({ "i", "n" }, "<CR>", on_select)
				map("n", "r", on_modify)

				return true
			end,
		})
		:find()
end

return M
