local M = {}

local function parse_arg(args, key)
	for i, v in ipairs(args) do
		if v == key then
			return args[i + 1]
		end
	end
end

local function delete_arg(args, key)
	local new_args = {}
	local skip_next = false
	for _, v in pairs(args) do
		if skip_next then
			skip_next = false
		elseif v == key then
			skip_next = true
		else
			table.insert(new_args, v)
		end
	end
	return new_args
end

local function pick_arg_with(args, str)
	for _, v in ipairs(args) do
		if string.find(v, str) then
			return v
		end
	end
end

--- @param config DebugConfig
M.pre_create = function(config)
	local new_config = vim.deepcopy(config)
	if new_config.dap_config["args"] and type(new_config.dap_config["args"]) == "table" then
		local new_args = vim.deepcopy(new_config.dap_config["args"])
		if parse_arg(new_args, "--runner") == "pytest" then
			new_args = delete_arg(new_args, "--results-file")
			new_args = delete_arg(new_args, "--stream-file")
			new_config.dap_config["args"] = new_args

			local test_target = pick_arg_with(new_args, "::")
			local test_name = test_target and test_target:gsub(".*::", "") or nil
			if test_name then
				new_config.name = new_config.name .. "::" .. test_name
			end
		end
	end
	return new_config
end

--- @param config DebugConfig
--- @return DebugConfig
M.pre_run = function(config)
	local new_config = vim.deepcopy(config)
	if new_config.dap_config["args"] and type(new_config.dap_config["args"]) == "table" then
		local new_args = vim.deepcopy(new_config.dap_config["args"])
		if parse_arg(new_args, "--runner") == "pytest" then
			table.insert(new_args, 1, "--results-file")
			table.insert(new_args, 2, vim.fn.tempname())
			table.insert(new_args, 1, "--stream-file")
			table.insert(new_args, 2, vim.fn.tempname())
			new_config.dap_config["args"] = new_args
		end
	end
	return new_config
end
return M
