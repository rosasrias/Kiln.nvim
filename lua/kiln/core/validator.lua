-- lua/kiln/core/validator.lua

local utils = require("kiln.utils")

local M = {}

function M.validate_project(project)
  local errors = {}
  local catalog = require("kiln.catalog")

  if not project.name or project.name == "" then
    table.insert(errors, "El nombre del proyecto es obligatorio.")
  end

  if not project.location or project.location == "" then
    table.insert(errors, "La ubicación del proyecto es obligatoria.")
  end

  if not catalog.is_valid(project.template) then
    table.insert(errors, "Template no soportado: " .. tostring(project.template))
  end

  -- sln no requiere namespace/framework
  if project.template ~= "sln" then
    if not utils.is_valid_namespace(project.namespace) then
      table.insert(errors, "El Namespace no es válido: " .. tostring(project.namespace))
    end
    if not project.framework or not project.framework:match("^net%d+%.%d+%-?%w*$") then
      table.insert(errors, "El Framework no es válido: " .. tostring(project.framework))
    end
  end

  return #errors == 0, errors
end

return M
