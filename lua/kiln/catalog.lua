-- lua/kiln/catalog.lua
-- Catálogo central de plantillas .NET (dotnet new) agrupadas como pide el usuario.
-- Cada entrada alimenta UI, generadores y README.

local M = {}

-- Definición canónica: key = identificador interno estable (usado en state.template)
-- dotnet_template = nombre para `dotnet new <name>` (informativo)
M.TEMPLATES = {
  -- 🖥️ General
  { key = "console",  label = "Console App",      category = "General",       icon = "", dotnet = "console",  description = "Console Application" },
  { key = "classlib", label = "Class Library",    category = "General",       icon = "", dotnet = "classlib", description = "Class Library" },
  { key = "worker",   label = "Worker Service",   category = "General",       icon = "󰡨", dotnet = "worker",   description = "Worker Service" },

  -- 🌐 ASP.NET Core
  { key = "webapi",     label = "Web API",          category = "ASP.NET Core", icon = "󰖟", dotnet = "webapi",     description = "ASP.NET Core Web API" },
  { key = "mvc",        label = "MVC",              category = "ASP.NET Core", icon = "󰖟", dotnet = "mvc",        description = "Web Application (MVC)" },
  { key = "razor",      label = "Razor Pages",      category = "ASP.NET Core", icon = "󰖟", dotnet = "webapp",     description = "Razor Pages" },
  { key = "blazor",     label = "Blazor",           category = "ASP.NET Core", icon = "󰖟", dotnet = "blazor",     description = "Blazor Web App" },
  { key = "blazorwasm", label = "Blazor WASM",      category = "ASP.NET Core", icon = "󰖟", dotnet = "blazorwasm", description = "Blazor WebAssembly" },
  { key = "empty",      label = "Empty Web",        category = "ASP.NET Core", icon = "󰖟", dotnet = "web",        description = "Empty Web" },

  -- 🔌 Servicios / comunicación
  { key = "grpc",       label = "gRPC Service",     category = "Servicios",    icon = "󰒍", dotnet = "grpc",       description = "gRPC Service" },

  -- 🖼️ Desktop
  { key = "wpf",          label = "WPF App",          category = "Desktop", icon = "󰙴", dotnet = "wpf",        description = "WPF Application" },
  { key = "wpf-lib",      label = "WPF Library",      category = "Desktop", icon = "󰙴", dotnet = "wpflib",     description = "WPF Class Library" },
  { key = "winforms",     label = "WinForms App",     category = "Desktop", icon = "󰙴", dotnet = "winforms",   description = "Windows Forms Application" },
  { key = "winforms-lib", label = "WinForms Library", category = "Desktop", icon = "󰙴", dotnet = "winformslib",description = "Windows Forms Class Library" },

  -- 🧪 Testing (NuGet, no Maven)
  { key = "xunit",  label = "xUnit",  category = "Testing", icon = "󰙨", dotnet = "xunit",  description = "xUnit Test Project" },
  { key = "nunit",  label = "NUnit",  category = "Testing", icon = "󰙨", dotnet = "nunit",  description = "NUnit Test Project" },
  { key = "mstest", label = "MSTest", category = "Testing", icon = "󰙨", dotnet = "mstest", description = "MSTest Test Project" },

  -- 📦 Soluciones / estructura
  { key = "sln", label = "Solution", category = "Solución", icon = "󰆼", dotnet = "sln", description = "Solution / Blank Solution" },
}

-- Orden de categorías para render
M.CATEGORY_ORDER = { "General", "ASP.NET Core", "Servicios", "Desktop", "Testing", "Solución" }

M.BY_KEY = {}
for _, t in ipairs(M.TEMPLATES) do M.BY_KEY[t.key] = t end

function M.is_valid(key) return M.BY_KEY[key] ~= nil end

function M.grouped()
  local out = {}
  local by_cat = {}
  for _, t in ipairs(M.TEMPLATES) do
    by_cat[t.category] = by_cat[t.category] or {}
    table.insert(by_cat[t.category], t)
  end
  for _, cat in ipairs(M.CATEGORY_ORDER) do
    if by_cat[cat] then table.insert(out, { category = cat, items = by_cat[cat] }) end
  end
  return out
end

-- Helpers para generadores
function M.is_web(key)
  return key == "webapi" or key == "mvc" or key == "razor" or key == "blazor" or key == "blazorwasm" or key == "empty" or key == "grpc"
end

function M.is_desktop(key)
  return key == "wpf" or key == "wpf-lib" or key == "winforms" or key == "winforms-lib"
end

function M.is_testing(key)
  return key == "xunit" or key == "nunit" or key == "mstest"
end

return M
