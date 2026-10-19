-- lua/kiln/core/scaffold.lua

local utils = require("kiln.utils")
local kinds = require("kiln.scaffold.kinds")
local templates = require("kiln.scaffold.templates")

local M = {}

M.CANDIDATES = {
  ".",
  "src/App",
  "src/Core",
  "src",
}

function M.find_roots(start_dir)
  local dir = utils.norm_dir(start_dir ~= "" and start_dir or vim.fn.getcwd())
  local found = {}
  while dir and dir ~= "" do
    for _, cand in ipairs(M.CANDIDATES) do
      local full = vim.fs.joinpath(dir, cand)
      if vim.fn.isdirectory(full) == 1 then
        -- consider root if contains .csproj or is project root
        local has_csproj = vim.fn.glob(vim.fs.joinpath(full, "*.csproj")) ~= ""
        if has_csproj or cand == "." then
          -- avoid duplicate "."
          local norm = utils.norm_dir(full)
          local exists = false
          for _, f in ipairs(found) do if f == norm then exists = true end end
          if not exists and (has_csproj or cand ~= ".") then
            -- for "." only add if it has csproj or sln
            if cand == "." then
              if vim.fn.glob(vim.fs.joinpath(full, "*.sln")) ~= "" or has_csproj then
                found[#found+1] = norm
              end
            else
              found[#found+1] = norm
            end
          end
        end
      end
    end
    local parent = utils.norm_dir(vim.fn.fnamemodify(dir, ":h"))
    if parent == dir then break end
    dir = parent
  end
  -- fallback: if no candidate, try cwd if has csproj
  if #found == 0 then
    local cwd = utils.norm_dir(vim.fn.getcwd())
    if cwd and (vim.fn.glob(vim.fs.joinpath(cwd, "*.csproj")) ~= "" or vim.fn.glob(vim.fs.joinpath(cwd, "*.sln")) ~= "") then
      found[1] = cwd
    end
  end
  return found
end

function M.detect_namespace(path, root)
  if not path or path == "" then return "" end
  path = utils.norm_dir(path)
  root = utils.norm_dir(root)
  if vim.fn.filereadable(path) == 1 then
    path = utils.norm_dir(vim.fn.fnamemodify(path, ":h"))
  end
  -- try to read RootNamespace from csproj
  local csproj = vim.fn.glob(vim.fs.joinpath(root, "*.csproj"))
  local base_ns = nil
  if csproj ~= "" then
    local content = utils.read_file(csproj)
    if content then base_ns = content:match("<RootNamespace>(.-)</RootNamespace>") end
  end
  if not base_ns then
    -- fallback to directory name or empty
    return ""
  end
  local ok_rel, relative = pcall(function() return (path:gsub("^" .. vim.pesc(root) .. "/?", "")) end)
  if not ok_rel or relative == path or relative == "" then
    return base_ns
  end
  -- relative like "Controllers/Sub" -> append to base_ns
  local suffix = relative:gsub("/", ".")
  if suffix ~= "" then return base_ns .. "." .. suffix end
  return base_ns
end

-- alias for compatibility
M.detect_package = M.detect_namespace

function M.pascal(name)
  name = tostring(name or "")
  name = name:gsub("[^%w%s%-%_]", "")
  local parts = {}
  for part in name:gmatch("[%w]+") do
    parts[#parts+1] = part:sub(1,1):upper() .. part:sub(2)
  end
  return table.concat(parts)
end

function M.target_file(root, ns, file_name)
  -- For C#, we place file directly under root if ns matches RootNamespace, otherwise subfolder
  -- Simplification: if ns differs from RootNamespace, create subfolder from suffix
  local dir = utils.norm_dir(root)
  -- try to infer base namespace
  local csproj = vim.fn.glob(vim.fs.joinpath(root, "*.csproj"))
  local base_ns = nil
  if csproj ~= "" then
    local content = utils.read_file(csproj)
    if content then base_ns = content:match("<RootNamespace>(.-)</RootNamespace>") end
  end
  if ns and ns ~= "" and base_ns and ns ~= base_ns then
    -- if ns starts with base_ns., then suffix is subpath
    if vim.startswith(ns, base_ns .. ".") then
      local suffix = ns:sub(#base_ns + 2)
      dir = vim.fs.joinpath(dir, utils.to_namespace_path(suffix))
    else
      -- fallback: full namespace path
      dir = vim.fs.joinpath(dir, utils.to_namespace_path(ns))
    end
  elseif ns and ns ~= "" and not base_ns then
    dir = vim.fs.joinpath(dir, utils.to_namespace_path(ns))
  end
  return vim.fs.joinpath(dir, file_name)
end

function M.create(opts)
  opts = opts or {}
  if not kinds.is_valid(opts.kind) then return false, "Tipo no soportado: " .. tostring(opts.kind), false end
  local name = M.pascal(opts.name)
  if name == "" then return false, "Nombre vacio", false end
  if not opts.root or vim.fn.isdirectory(opts.root) == 0 then return false, "Raiz C# no encontrada (abre un proyecto)", false end

  local file_name = name .. ".cs"
  local suffixes = {
    controller = "Controller",
    service = "Service",
    repository = "Repository",
  }
  local base = kinds.BY_KEY[opts.kind].label
  if suffixes[opts.kind] then
    file_name = name .. suffixes[opts.kind] .. ".cs"
  elseif opts.kind == "entity" then
    file_name = name .. ".cs"
  elseif base == "Class" or base == "Interface" then
    file_name = name .. ".cs"
  end

  local path = M.target_file(opts.root, opts.pkg, file_name)
  local existed = vim.fn.filereadable(path) == 1
  if existed and not opts.force then return false, "El archivo ya existe: " .. path, true end

  local content = templates.render(opts.kind, opts.pkg, name, { values = opts.values, params = opts.params })
  if not content then return false, "Sin template para: " .. opts.kind, false end
  utils.ensure_dir(vim.fs.dirname(path))
  utils.write_file(path, content)
  return true, path, existed
end

function M.create_package(opts)
  opts = opts or {}
  local pkg = (opts.pkg or ""):gsub("%s", "")
  if pkg == "" then return false, "Namespace vacio" end
  if not opts.root or vim.fn.isdirectory(opts.root) == 0 then return false, "Raiz C# no encontrada" end
  -- For C#, package is namespace suffix folder
  local dir = M.target_file(opts.root, pkg, "x")
  dir = vim.fs.dirname(dir)
  utils.ensure_dir(dir)
  return true, dir
end

local function sans_known_suffixes(base)
  return (base:gsub("(Controller|Service|Repository)$", ""))
end

local function cs_root_of(path)
  local dir = utils.norm_dir(vim.fs.dirname(path))
  while dir and dir ~= "" do
    for _, cand in ipairs(M.CANDIDATES) do
      if dir:sub(-#cand) == cand or cand == "." then
        -- check if contains csproj
        if vim.fn.glob(vim.fs.joinpath(dir, "*.csproj")) ~= "" then return dir end
      end
    end
    local parent = utils.norm_dir(vim.fn.fnamemodify(dir, ":h"))
    if parent == dir then break end
    dir = parent
  end
  return nil
end

local function prune_empty_dirs(from, upto)
  local d = from
  while d and #d > #upto and vim.fn.isdirectory(d) == 1 do
    if #vim.fn.readdir(d) > 0 then break end
    vim.fn.delete(d, "d")
    d = utils.norm_dir(vim.fn.fnamemodify(d, ":h"))
  end
end

function M.find_by_name(name, opts)
  opts = opts or {}
  local norm = M.pascal(name)
  if norm == "" then return {} end
  local roots = opts.roots or M.find_roots(opts.start_dir or vim.fn.getcwd())
  local out = {}
  local seen = {}
  for _, root in ipairs(roots) do
    local matches = vim.fs.find({ norm .. ".cs" }, { path = root, type = "file", limit = 200 })
    for _, p in ipairs(matches) do
      p = utils.norm_dir(p)
      if not seen[p] then
        seen[p] = true
        out[#out+1] = { path = p, root = root, pkg = M.detect_namespace(p, root) }
      end
    end
  end
  table.sort(out, function(a,b) return a.path < b.path end)
  return out
end

function M.related_tests(path)
  if not path or vim.fn.filereadable(path) == 0 then return {} end
  path = utils.norm_dir(path)
  local base = vim.fn.fnamemodify(path, ":t:r")
  local candidates = { base .. "Tests", base .. "Test" }
  local bare = sans_known_suffixes(base)
  if bare ~= base then candidates[#candidates+1] = bare .. "Tests" end
  local out = {}
  for _, cand in ipairs(candidates) do
    -- tests often in tests/ folder
    local tpath = path:gsub("/src/", "/tests/")
    tpath = vim.fs.joinpath(vim.fs.dirname(tpath), cand .. ".cs")
    tpath = utils.norm_dir(tpath)
    if tpath ~= path and vim.fn.filereadable(tpath) == 1 then out[#out+1] = tpath end
    -- also same folder sibling
    local sibling = vim.fs.joinpath(vim.fs.dirname(path), cand .. ".cs")
    if vim.fn.filereadable(sibling) == 1 then out[#out+1] = utils.norm_dir(sibling) end
  end
  return out
end

function M.delete_files(paths)
  local res = { deleted = {}, missing = {} }
  for _, p in ipairs(paths or {}) do
    p = utils.norm_dir(p)
    if vim.fn.filereadable(p) == 1 then
      local dir = vim.fs.dirname(p)
      local root = cs_root_of(p)
      vim.fn.delete(p)
      res.deleted[#res.deleted+1] = p
      if root then prune_empty_dirs(dir, root) end
    else
      res.missing[#res.missing+1] = p
    end
  end
  return res
end

return M
