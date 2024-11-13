---@class Config
---@field name string
---@field serialize fun(self): string
---@field modify fun(self): nil
---@field sortkey fun(self): number
---@field detail fun(self): string
---@field run fun(self): nil

---@class ConfigEntity
---@field id string
---@field config Config

---@class Module
---@field deserialize fun(str: string): Config
---@field setup fun(opts: table): nil
---@field create fun(on_created: fun(config: Config): nil): nil

--- @class Options
--- @field save_file string
--- @field save_dir string
--- @field types string[]
