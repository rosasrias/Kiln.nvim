local M = {}

------------------------------------------------------------
-- Filesystem
------------------------------------------------------------

function M.ensure_dir(path)
  if not path or path == "" then
    return
  end
  vim.fn.mkdir(path, "p")
end

function M.write_file(path, content)
  local dir = vim.fs.dirname(path)
  M.ensure_dir(dir)
  vim.fn.writefile(
    vim.split(content, "\n", { plain = true }),
    path
  )
end

function M.read_file(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  return table.concat(
    vim.fn.readfile(path),
    "\n"
  )
end

------------------------------------------------------------
-- String
------------------------------------------------------------

function M.truncate(value, maxw)
  value = tostring(value or "")
  if vim.fn.strwidth(value) <= maxw then
    return value
  end
  return vim.fn.strcharpart(value, 0, math.max(0, maxw - 1)) .. "…"
end

function M.slug(value)
  value = tostring(value or "")
  value = value:lower()
  value = value:gsub("[^%w%s%-_]", "")
  value = value:gsub("[%s_]+", "-")
  value = value:gsub("%-+", "-")
  value = value:gsub("^%-", "")
  value = value:gsub("%-$", "")
  return value
end

function M.to_namespace_path(ns)
  return (ns:gsub("%.", "/"))
end

-- alias for compatibility
M.to_package_path = M.to_namespace_path

function M.is_valid_identifier(value)
  return type(value) == "string"
      and value ~= ""
      and value:match("^[%a_][%w_]*$")
end

function M.is_valid_package(value)
  if not value or value == "" then
    return false
  end
  for part in value:gmatch("[^.]+") do
    if not M.is_valid_identifier(part) then
      return false
    end
  end
  return true
end

M.is_valid_namespace = M.is_valid_package

function M.to_pascal(value)
  value = tostring(value or "")
  value = value:gsub("[^%w%s%-%_]", "")
  local parts = {}
  for part in value:gmatch("[%w]+") do
    parts[#parts + 1] = part:sub(1,1):upper() .. part:sub(2)
  end
  return table.concat(parts)
end

------------------------------------------------------------
-- .NET SDK detection
------------------------------------------------------------

function M.parse_dotnet_version(raw)
  if not raw then return nil end
  -- "8.0.413" or "8.0.100" -> 8
  local major = raw:match("^(%d+)%.%d+")
  if major then return tonumber(major) end
  -- dotnet --version single line "8.0.413"
  major = raw:match("(%d+)%.")

  return major and tonumber(major) or nil
end

function M.get_dotnet_version(dotnet_bin)
  local result = vim.system(
    { dotnet_bin, "--version" },
    { text = true }
  ):wait()
  if not result then return nil end
  local out = result.stdout or ""
  -- first line is version
  local ver = out:match("([%d]+%.[%d]+%.[%d]+)")
  if not ver then
    ver = vim.trim(out:match("([^\r\n]+)") or "")
  end
  if ver == "" then return nil end
  return M.parse_dotnet_version(ver), ver
end

function M.detect_sdks()
  local sdks = {}
  local seen = {}

  local function add(path, version_str, label)
    if not path or path == "" then return end
    local key = path:lower():gsub("\\", "/")
    if seen[key] then return end
    local version_num = M.parse_dotnet_version(version_str)
    if not version_num then return end
    seen[key] = true
    table.insert(sdks, {
      path = path,
      version = version_num,
      version_str = version_str,
      label = label or ("SDK " .. version_str),
    })
  end

  -- Execute dotnet --list-sdks
  if vim.fn.executable("dotnet") == 1 then
    local dotnet_bin = vim.fn.exepath("dotnet")
    local res = vim.system({ dotnet_bin, "--list-sdks" }, { text = true }):wait()
    if res and res.code == 0 and res.stdout then
      for line in res.stdout:gmatch("[^\r\n]+") do
        -- lines like "8.0.413 [C:\Program Files\dotnet\sdk]"
        local ver, sdk_path = line:match("([%d%.]+)%s+%[(.+)%]")
        if ver and sdk_path then
          local bin = vim.fs.joinpath(vim.trim(sdk_path), ver, "dotnet")
          if vim.fn.has("win32") == 1 then bin = bin .. ".exe" end
          -- use dotnet exe itself as identifier; but we need sdk path
          add(sdk_path, ver, "SDK " .. ver)
        end
      end
    end
    -- fallback: dotnet --version
    if #sdks == 0 then
      local vnum, vstr = M.get_dotnet_version(dotnet_bin)
      if vnum then
        add(dotnet_bin, vstr or tostring(vnum), "dotnet (PATH)")
      end
    end
  end

  -- DOTNET_ROOT
  local dotnet_root = vim.fn.getenv("DOTNET_ROOT")
  if dotnet_root and dotnet_root ~= vim.NIL and vim.fn.isdirectory(dotnet_root) == 1 then
    local sdk_dir = vim.fs.joinpath(dotnet_root, "sdk")
    local h = vim.uv.fs_scandir(sdk_dir)
    if h then
      while true do
        local name, type = vim.uv.fs_scandir_next(h)
        if not name then break end
        if type == "directory" then
          add(vim.fs.joinpath(sdk_dir, name), name, name)
        end
      end
    end
  end

  -- Windows common location
  if vim.fn.has("win32") == 1 then
    local roots = { "C:\\Program Files\\dotnet\\sdk", "C:\\Program Files (x86)\\dotnet\\sdk" }
    for _, root in ipairs(roots) do
      local h = vim.uv.fs_scandir(root)
      if h then
        while true do
          local name, type = vim.uv.fs_scandir_next(h)
          if not name then break end
          if type == "directory" then
            add(vim.fs.joinpath(root, name), name, name)
          end
        end
      end
    end
  else
    local roots = { "/usr/share/dotnet/sdk", "/usr/local/share/dotnet/sdk", "/opt/dotnet/sdk" }
    for _, root in ipairs(roots) do
      local h = vim.uv.fs_scandir(root)
      if h then
        while true do
          local name, type = vim.uv.fs_scandir_next(h)
          if not name then break end
          if type == "directory" then
            add(vim.fs.joinpath(root, name), name, name)
          end
        end
      end
    end
  end

  table.sort(sdks, function(a, b)
    if a.version ~= b.version then return a.version > b.version end
    -- desempate por version_str completo (ej: 10.0.400 vs 10.0.200)
    local function parse_full(v)
      local maj, min, pat = v:match("(%d+)%.(%d+)%.(%d+)")
      return tonumber(maj) or 0, tonumber(min) or 0, tonumber(pat) or 0
    end
    local amaj, amin, apat = parse_full(a.version_str or "")
    local bmaj, bmin, bpat = parse_full(b.version_str or "")
    if amin ~= bmin then return amin > bmin end
    return apat > bpat
  end)
  return sdks
end

-- Helpers dinámicos para frameworks (TFM)
function M.get_available_frameworks()
  local sdks = M.detect_sdks()
  local majors = {}
  local seen = {}
  for _, s in ipairs(sdks) do
    if s.version and not seen[s.version] then
      seen[s.version] = true
      table.insert(majors, s.version)
    end
  end
  -- Fallback: asegurar que siempre hay opciones aunque no haya SDK instalado (plugin genera sin dotnet)
  -- Incluir última LTS + preview: 10,9,8,7,6
  for _, v in ipairs({ 10, 9, 8, 7, 6 }) do
    if not seen[v] then
      table.insert(majors, v)
      seen[v] = true
    end
  end
  table.sort(majors, function(a, b) return a > b end)
  local out = {}
  for _, major in ipairs(majors) do
    table.insert(out, string.format("net%d.0", major))
  end
  return out
end

function M.get_latest_framework()
  local sdks = M.detect_sdks()
  local max = 0
  for _, s in ipairs(sdks) do
    if s.version and s.version > max then max = s.version end
  end
  if max > 0 then return string.format("net%d.0", max) end
  -- sin SDK, usar último conocido estable (10)
  return "net10.0"
end

function M.framework_package_version(framework, fallback)
  local major = framework and framework:match("net(%d+)%.")
  if major then return string.format("%s.0.0", major) end
  return fallback or "10.0.0"
end

-- alias for compatibility with javaforge naming
M.detect_jdks = M.detect_sdks
M.get_java_version = M.get_dotnet_version
M.parse_java_version = M.parse_dotnet_version

------------------------------------------------------------
-- Ubicaciones recientes
------------------------------------------------------------

M.recents_path = nil
local MAX_RECENTS = 10

local function recents_file()
  return M.recents_path or vim.fn.stdpath("data") .. "/kiln_locations"
end

function M.norm_dir(path)
  if not path or path == "" then return nil end
  local p = vim.fn.fnamemodify(path, ":p")
  p = p:gsub("\\", "/")
  if #p > 3 then p = p:gsub("/+$", "") end
  if p == "" then return nil end
  return p
end

function M.load_recent_dirs()
  local file = recents_file()
  local content = M.read_file(file)
  if not content then return {} end
  local out = {}
  for _, line in ipairs(vim.split(content, "\n")) do
    local dir = M.norm_dir(line)
    if dir and vim.fn.isdirectory(dir) == 1 then
      table.insert(out, dir)
    end
  end
  return out
end

function M.push_recent_dir(path)
  local dir = M.norm_dir(path)
  if not dir or vim.fn.isdirectory(dir) ~= 1 then return end
  local list = { dir }
  for _, existing in ipairs(M.load_recent_dirs()) do
    if existing ~= dir then table.insert(list, existing) end
  end
  while #list > MAX_RECENTS do table.remove(list) end
  M.write_file(recents_file(), table.concat(list, "\n"))
end

function M.location_candidates(start)
  local out = {}
  local seen = {}
  local function add(path)
    local dir = M.norm_dir(path)
    if not dir then return end
    if seen[dir] then return end
    if vim.fn.isdirectory(dir) ~= 1 then return end
    seen[dir] = true
    table.insert(out, dir)
  end
  for _, dir in ipairs(M.load_recent_dirs()) do add(dir) end
  local current = M.norm_dir(start)
  for _ = 1, 8 do
    if not current then break end
    add(current)
    local parent = M.norm_dir(vim.fn.fnamemodify(current, ":h"))
    if parent == current then break end
    current = parent
  end
  return out
end

return M
