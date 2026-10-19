-- lua/kiln/health.lua

local M = {}
local is_win = vim.fn.has("win32") == 1

local function has(bin) return vim.fn.executable(bin) == 1 end

local function probe(bin, args)
  local argv = { bin }
  vim.list_extend(argv, args)
  if is_win then argv = vim.list_extend({ "cmd.exe", "/C" }, argv) end
  local ok, res = pcall(function() return vim.system(argv, { text = true }):wait() end)
  if not ok or not res or res.code ~= 0 then return nil end
  local out = res.stdout ~= "" and res.stdout or res.stderr
  if not out or out == "" then return nil end
  return vim.trim(out:match("([^\r\n]+)"))
end

local function start(name) vim.health.start(name) end

local function check_volt()
  start("volt (dependencia)")
  local ok, volt = pcall(require, "volt")
  if ok and volt then vim.health.ok("volt cargado correctamente")
  else vim.health.error("volt no esta disponible en runtimepath", { ":git clone https://github.com/NvChad/volt en tu rtp" }) end
end

local function check_dotnet()
  start(".NET SDK")
  if not has("dotnet") then
    vim.health.error("dotnet no se encontro en PATH", { "Instala .NET SDK desde https://dotnet.microsoft.com/download" })
    return
  end
  local version = probe("dotnet", { "--version" })
  if version then vim.health.ok(version) else vim.health.warn("dotnet existe pero no respondio a --version") end
  local utils = require("kiln.utils")
  local sdks = utils.detect_sdks()
  if #sdks == 0 then
    vim.health.warn("el wizard no detecto ningun SDK", { "podras escribir la version manualmente, pero el selector quedara vacio" })
    return
  end
  for _, s in ipairs(sdks) do vim.health.info(string.format("%s -> %s", s.label, s.path)) end
  local list = probe("dotnet", { "--list-sdks" })
  if list then vim.health.info(list) end
end

local function check_git()
  start("Git")
  if not has("git") then vim.health.warn("git no esta instalado", { "la feature 'Create Git repository' omitira git init" }) return end
  local version = probe("git", { "--version" })
  if version then vim.health.ok(version) else vim.health.warn("git existe pero no respondio a --version") end
end

function M.check()
  check_volt()
  check_dotnet()
  check_git()
end

return M
