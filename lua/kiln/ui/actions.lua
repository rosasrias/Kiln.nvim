-- lua/kiln/ui/actions.lua

local state = require("kiln.state")
local utils = require("kiln.utils")
local project_core = require("kiln.core.project")
local validator = require("kiln.core.validator")
local window = require("kiln.ui.window")
local input = require("kiln.ui.input")

local M = {}

M.sdks = {}
M.sdk_index = 0

function M.prepare_session()
  state.reset()
  M.sdks = utils.detect_sdks()
  M.sdk_index = 1
  if M.sdks[1] then state.get().sdk = M.sdks[1] end
  local project = state.get()
  -- Sincronizar framework con el SDK detectado (net10.0 para 10.0.400, etc.)
  -- Solo si el usuario no forzó un default_framework distinto al auto-detectado
  local latest = utils.get_latest_framework()
  -- si el config default es net10.0/genérico, usar el último detectado; si el usuario configuró otro, respetarlo
  -- Pero si hay SDK detectado y el framework actual no coincide con el mayor, actualizar
  if latest and M.sdks[1] then
    local configured = state.config.project.default_framework
    -- si no hay config específica o es la default, usar latest; además si no hay SDK, mantener default
    if not configured or configured == "net10.0" or configured == "net8.0" or configured == "net9.0" then
      project.framework = latest
    end
    -- Asegurar que FRAMEWORKS incluya el latest
    local found = false
    for _, v in ipairs(M.FRAMEWORKS) do if v == latest then found = true break end end
    if not found then table.insert(M.FRAMEWORKS, 1, latest) end
  end
  project.location = state.config.project.default_location or utils.load_recent_dirs()[1] or vim.fn.getcwd()
end

function M.pick_location()
  local candidates = utils.location_candidates(state.get().location)
  if #candidates == 0 then vim.notify("Kiln: sin ubicaciones candidatas", vim.log.levels.WARN) return end
  input.close()
  vim.ui.select(candidates, {
    prompt = "Ubicacion del proyecto",
    format_item = function(item)
      local current = utils.norm_dir(state.get().location)
      if item == current then return item .. "  (actual)" end
      return item
    end,
  }, function(choice)
    if not choice then return end
    state.get().location = choice
    window.redraw("body")
  end)
end

local function redraw_body() window.redraw("body") end
local function clear_errors() state.update({ errors = {} }) end

function M.sync_defaults()
  local project = state.get()
  if project.name == "" then return end
  local slug = utils.slug(project.name)
  local pascal = utils.to_pascal(project.name)
  if not state.is_edited("namespace") then
    project.namespace = pascal
  end
  -- artifact not needed but keep for future
end

function M.set_template(tpl)
  local project = state.get()
  project.template = tpl
  clear_errors()
  redraw_body()
end

function M.toggle_webapi_feature(key)
  local project = state.get()
  if project.template ~= "webapi" then return end
  local web = project.webapi
  if not web or web[key] == nil then return end
  web[key] = not web[key]
  clear_errors()
  redraw_body()
end

-- aliases for java compatibility
M.toggle_starter = M.toggle_webapi_feature
M.set_tool = function(_) redraw_body() end

function M.cycle_sdk()
  if #M.sdks == 0 then vim.notify("Kiln: no se detectaron SDKs", vim.log.levels.WARN) return end
  M.sdk_index = (M.sdk_index % #M.sdks) + 1
  state.get().sdk = M.sdks[M.sdk_index]
  clear_errors()
  redraw_body()
end

M.cycle_jdk = M.cycle_sdk

M.FRAMEWORKS = { "net10.0", "net9.0", "net8.0", "net7.0" }
-- also 10 preview
-- Provide modern list
M.DOTNET_VERSIONS = { "net10.0", "net9.0", "net8.0", "net7.0" }

function M.cycle_framework()
  local project = state.get()
  -- Usar lista dinámica basada en SDKs instalados para ser future-proof (net11, net12...)
  local frameworks = utils.get_available_frameworks()
  -- si la lista dinámica es más completa, usarla
  if #frameworks > #M.FRAMEWORKS then
    -- asegurar que contiene el framework actual
    local found = false
    for _, v in ipairs(frameworks) do if v == project.framework then found = true break end end
    if not found then table.insert(frameworks, project.framework) end
  else
    frameworks = M.FRAMEWORKS
    -- complementar con dinámicos no incluidos (ej: net11 detectado)
    local dyn = utils.get_available_frameworks()
    for _, v in ipairs(dyn) do
      local exists = false
      for _, f in ipairs(frameworks) do if f == v then exists = true break end end
      if not exists then table.insert(frameworks, v) end
    end
    -- ordenar desc para que el ciclo sea predecible
    table.sort(frameworks, function(a,b)
      local ma = tonumber(a:match("net(%d+)")) or 0
      local mb = tonumber(b:match("net(%d+)")) or 0
      return ma > mb
    end)
  end
  local current = project.framework
  local pos = 0
  for i, v in ipairs(frameworks) do if v == current then pos = i break end end
  local nextv = frameworks[(pos % #frameworks) + 1]
  project.framework = nextv
  clear_errors()
  redraw_body()
end

M.cycle_java_version = M.cycle_framework
M.JAVA_VERSIONS = { 10, 9, 8 }

function M.submit()
  if input.is_active() then return end
  local project = state.get()
  M.sync_defaults()
  local valid, errors = validator.validate_project(project)
  if not valid then state.update({ errors = errors }) redraw_body() return end
  clear_errors()
  local ok, root = project_core.create(project)
  if not ok then return end
  utils.push_recent_dir(project.location)
  window.close()
  if not project.features.sample_code then
    vim.schedule(function() vim.cmd("edit " .. vim.fn.fnameescape(root)) end)
    return
  end
  local main_file = "Program.cs"
  local main_path = root
  if project.features.multi_project then main_path = vim.fs.joinpath(root, "src", "App") end
  vim.schedule(function()
    local candidate = vim.fs.joinpath(main_path, main_file)
    -- for webapi also Program.cs
    if vim.fn.filereadable(candidate) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(candidate))
    else
      vim.cmd("edit " .. vim.fn.fnameescape(root))
    end
  end)
end

return M
