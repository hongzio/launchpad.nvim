local M = {}

--- @param file string @Path to the file
--- @return table
function M.read_json_file(file)
	local f = io.open(file, "r")
	if f then
		local content = f:read("*all")
		f:close()
		return vim.fn.json_decode(content)
	end
	return {}
end

--- @param file string @Path to the file
--- @param data table @Data to write
function M.write_json_file(file, data)
	local f = io.open(file, "w")
	if f then
		f:write(vim.fn.json_encode(data))
		f:close()
	end
end

--- @param env_str string @String containing environment variables
--- @return table<string, string> @Table containing environment variables
function M.parse_env_vars(env_str)
	local env = {}
	for line in env_str:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.+)$")
		if key and value then
			env[key] = value
		else
			error("Invalid environment variable: " .. line)
		end
	end
	return env
end

--- @param env_vars table<string, string> @Table containing environment variables
--- @return string @String containing environment variables
function M.stringify_env_vars(env_vars)
  local env_str = ""
  for key, value in pairs(env_vars) do
    env_str = env_str .. key .. "=" .. value .. "\n"
  end
  return env_str
end

function M.load_env_file(file)
  local f = io.open(file, "r")
  if f then
    local content = f:read("*all")
    f:close()
    return M.parse_env_vars(content)
  end
  return {}
end


math.randomseed(os.time())
function M.uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

return M
