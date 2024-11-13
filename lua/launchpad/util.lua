local M = {}

--- @param file string @Path to the file
--- @return table
function M.read_json_file(file)
	local f = io.open(file, "r")
	if not f then
		return {}
	end

	local content = f:read("*all")
	f:close()
	if content == "" then
		return {}
	end
	return vim.fn.json_decode(content)
end

--- @param file string @Path to the file
--- @param data table @Data to write
function M.write_json_file(file, data)
	local f = io.open(file, "w")
	if not f then
		return
	end

	f:write(vim.fn.json_encode(data))
	f:close()
end

--- @param env_str string @String containing environment variables
--- @return table<string, string> @Table containing environment variables
function M.parse_env_vars(env_str)
	local env = {}
	for line in env_str:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.+)$")
		if not key or not value then
			error("Invalid environment variable: " .. line)
		end
		env[key] = value
	end
	return env
end

--- @param env_vars table<string, string> @Table containing environment variables
--- @return string @String containing environment variables
function M.stringify_env_vars(env_vars)
	local env_str = {}
	for key, value in pairs(env_vars) do
		table.insert(env_str, key .. "=" .. value)
	end
	return table.concat(env_str, "\n")
end

--- @param file string @Path to the file
--- @return table<string, string> @Table containing environment variables
function M.load_env_file(file)
	local f = io.open(file, "r")
	if not f then
		vim.notify(
			"Could not open env file: " .. file .. ". Current working directory: " .. vim.fn.getcwd(),
			vim.log.levels.ERROR
		)
		return {}
	end

	local content = f:read("*all")
	f:close()
	return M.parse_env_vars(content)
end

math.randomseed(os.time())
function M.uuid()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format("%x", v)
	end)
end

local function is_array(t)
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then
			return false
		end
	end
	return true
end

local indent_unit = 2
--- @param obj any @Object to beautify
--- @param indent number @Indentation level
--- @return string @Beautified JSON
local function beautify_json_object(obj, indent)
	if type(obj) == "table" then
		if is_array(obj) then
			local ret = "[\n"
			local lines = {}
			for _, v in ipairs(obj) do
				lines[#lines + 1] = string.rep(" ", indent + indent_unit)
					.. beautify_json_object(v, indent + indent_unit)
			end
			ret = ret .. table.concat(lines, ",\n") .. "\n"
			return ret .. string.rep(" ", indent) .. "]"
		else
			local ret = "{\n"
			local lines = {}
			for k, v in pairs(obj) do
				lines[#lines + 1] = string.rep(" ", indent + indent_unit)
					.. '"'
					.. k
					.. '": '
					.. beautify_json_object(v, indent + indent_unit)
			end
			ret = ret .. table.concat(lines, ",\n") .. "\n"
			return ret .. string.rep(" ", indent) .. "}"
		end
	elseif type(obj) == "string" then
		return '"' .. obj .. '"'
	elseif type(obj) == "number" then
		return tostring(obj)
	elseif type(obj) == "boolean" then
		return tostring(obj)
	else
		return tostring(obj)
	end
end

--- @param str string @Json string
--- @return string @Beautified JSON
function M.beautify_json(str)
	local obj = vim.fn.json_decode(str)
	return beautify_json_object(obj, 0)
end

return M
