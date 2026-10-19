local utils = require("kiln.utils")

local M = {}

function M.find_root(start)
  local dir = vim.fs.normalize(start or vim.fn.getcwd())
  while dir and dir ~= "" do
    -- .sln
    local sln = vim.fn.glob(vim.fs.joinpath(dir, "*.sln"))
    if sln ~= "" then return dir, "dotnet" end
    -- any csproj
    local csproj = vim.fn.glob(vim.fs.joinpath(dir, "*.csproj"))
    if csproj ~= "" then return dir, "dotnet" end
    -- also check nested sdk style: search for csproj recursively one level?
    local found = vim.fs.find(function(name, path) return name:match("%.csproj$") end, { path = dir, type = "file", limit = 1 })
    if #found > 0 then
      -- only if directly under dir? find_root scans parents, so we need to check current dir contains csproj via glob above
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return nil, nil
end

local function detect_namespace(file)
  local content = utils.read_file(file)
  if not content then return nil end
  return content:match("namespace%s+([%w_%.]+)%s*[;{]")
end

local function detect_main(file)
  local content = utils.read_file(file)
  if not content then return nil end
  if content:match("static%s+void%s+Main") or content:match("static%s+async%s+Task%s+Main") or content:match("WebApplication") then
    local ns = detect_namespace(file)
    local cls = content:match("class%s+([%w_]+)")
    if ns and cls then return ns .. "." .. cls end
    return cls
  end
  return nil
end

local function scan_cs(root)
  for file, type in vim.fs.dir(root, { recursive = true }) do
    if type == "file" and file:match("%.cs$") then
      local full = vim.fs.joinpath(root, file)
      local detected = detect_main(full)
      if detected then return detected end
    end
  end
  return nil
end

local function detect_csproj_info(root)
  local cs = vim.fn.glob(vim.fs.joinpath(root, "*.csproj"))
  if cs == "" then
    -- search one level deep
    local found = vim.fs.find(function(n) return n:match("%.csproj$") end, { path = root, type = "file", limit = 5 })
    if #found > 0 then cs = found[1] end
  end
  if cs == "" or cs == nil then return {} end
  local content = utils.read_file(cs)
  if not content then return {} end
  return {
    target_framework = content:match("<TargetFramework>(.-)</TargetFramework>"),
    root_namespace = content:match("<RootNamespace>(.-)</RootNamespace>"),
  }
end

function M.detect(start)
  local root, build_tool = M.find_root(start)
  if not root then return nil end
  local csinfo = detect_csproj_info(root)
  local project = {
    root = root,
    name = vim.fs.basename(root),
    build_tool = build_tool or "dotnet",
    main_class = scan_cs(root),
    framework = csinfo.target_framework,
    namespace = csinfo.root_namespace,
  }
  return project
end

return M
