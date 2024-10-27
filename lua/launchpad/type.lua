local M = {}

--- @class EnvVar
--- @field key string
--- @field value string
local EnvVar = {}

function EnvVar.new()
	local self = {}
	setmetatable(self, { __index = EnvVar })
	return self
end


M.EnvVar = EnvVar
return M
