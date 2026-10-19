-- lua/kiln/scaffold/kinds.lua

local M = {}

M.BY_KEY = {
  class      = { label = "Class",      icon = "󰎙", desc = "Crear clase" },
  interface  = { label = "Interface",  icon = "󰠱", desc = "Crear interface" },
  record     = { label = "Record",     icon = "󰑋", desc = "Crear record" },
  enum       = { label = "Enum",       icon = "󰘳", desc = "Crear enum" },
  struct     = { label = "Struct",     icon = "󰊠", desc = "Crear struct" },
  exception  = { label = "Exception",  icon = "", desc = "Crear exception" },

  entity     = { label = "Entity",     icon = "󰎁", desc = "Entidad EF Core" },
  controller = { label = "Controller", icon = "", desc = "Controller WebAPI" },
  service    = { label = "Service",    icon = "", desc = "Service" },
  repository = { label = "Repository", icon = "󰨸", desc = "Repository" },
  worker     = { label = "Worker",     icon = "󰡌", desc = "BackgroundService" },
}

M.GROUPS = {
  { title = "basic",  keys = { "class", "interface", "record", "enum", "struct", "exception" } },
  { title = "webapi", keys = { "entity", "controller", "service", "repository", "worker" } },
}

function M.is_valid(key)
  return key ~= nil and M.BY_KEY[key] ~= nil
end

return M
