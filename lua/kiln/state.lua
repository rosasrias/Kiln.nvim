-- lua/kiln/state.lua

local M = {}

--- @class KilnFeatures
--- @field git boolean
--- @field sample_code boolean
--- @field tests boolean

M.config = {
  project = {
    default_location = nil,
    default_namespace = "MyApp",
    default_framework = "net10.0",
    default_sdk = nil,
    default_template = "console",
  },
  git = {
    enabled = true,
  },
}

---@type table
M.project = {}

function M.setup(opts)
  vim.validate({ opts = { opts, "table", true } })
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.reset()
  local config = M.config
  -- si no hay default_framework, intentar detectar el último SDK instalado
  local default_fw = config.project.default_framework
  if not default_fw or default_fw == "" then
    local ok_utils, u = pcall(require, "kiln.utils")
    if ok_utils and u and u.get_latest_framework then
      default_fw = u.get_latest_framework()
    else
      default_fw = "net10.0"
    end
  end
  M.project = {
    name = "",
    location = config.project.default_location or vim.fn.getcwd(),
    language = "csharp",
    sdk = config.project.default_sdk,
    framework = default_fw or "net10.0",
    namespace = config.project.default_namespace or "MyApp",
    template = "console",
    webapi = {
      auth = false,
      efcore = false,
      swagger = true,
    },
    features = {
      git = config.git.enabled,
      sample_code = true,
      tests = true,
      meta_files = true,
      multi_project = false,
      docker = false,
    },
    errors = {},
    edited = {},
  }
  return M.project
end

function M.mark_edited(key)
  M.project.edited[key] = true
end

function M.is_edited(key)
  return M.project.edited[key] == true
end

function M.get()
  return M.project
end

function M.update(data)
  M.project = vim.tbl_deep_extend("force", M.project, data or {})
  return M.project
end

return M
