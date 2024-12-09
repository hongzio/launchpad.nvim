---@class Config
---@field name string
---@field serialize fun(self): string
---@field modify fun(self, callback): nil
---@field sort_key fun(self): number
---@field hash_key fun(self): string
---@field detail fun(self): string
---@field run fun(self): nil

---@class ConfigEntity
---@field id string
---@field hash string
---@field config Config

---@class Module
---@field deserialize fun(str: string): Config
---@field setup fun(opts: table): nil
---@field create fun(on_created: fun(config: Config): nil): nil

--- @class Options
--- @field save_file string
--- @field save_dir string
--- @field types string[]
