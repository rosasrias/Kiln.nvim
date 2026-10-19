-- tests/run.lua for kiln
local failures = 0
local function ok(cond, msg)
  if cond then print("[PASS] " .. msg) else print("[FAIL] " .. msg) failures = failures + 1 end
end
local function eq(a,b,msg) ok(a==b, msg .. string.format(" (esperado=%s obtenido=%s)", tostring(b), tostring(a))) end
local function isdir(p) return vim.fn.isdirectory(p)==1 end

local mods = {
  "kiln","kiln.state","kiln.utils","kiln.mappings","kiln.ui","kiln.ui.window","kiln.ui.input","kiln.ui.actions","kiln.ui.views.new_project","kiln.ui.highlights","kiln.ui.components","kiln.core.detector","kiln.core.project","kiln.core.validator","kiln.generators","kiln.generators.console","kiln.generators.webapi","kiln.generators.wpf","kiln.generators.docker","kiln.health",
}
for _, m in ipairs(mods) do
  local loaded, err = pcall(require, m)
  ok(loaded, "carga modulo " .. m .. (loaded and "" or (" -> " .. tostring(err))))
end

-- API publica
local kiln = require("kiln")
ok(type(kiln.setup) == "function", "kiln.setup existe")
ok(type(kiln.open) == "function", "kiln.open existe")
ok(type(kiln.close) == "function", "kiln.close existe")
local setup_ok, setup_err = pcall(kiln.setup, { project = { default_template = "webapi" }, git = { enabled = false } })
ok(setup_ok, "kiln.setup acepta configuracion" .. (setup_ok and "" or (" -> " .. tostring(setup_err))))
local st_config = require("kiln.state").config
eq(st_config.project.default_template, "webapi", "setup aplica default_template")
eq(st_config.git.enabled, false, "setup aplica git.enabled")
require("kiln.state").setup({ project = { default_template = "console" }, git = { enabled = true } })

-- comandos publicos
local function cmd_exists(name) return vim.fn.exists(":" .. name) == 2 end
for _, name in ipairs({ "KilnProject", "KilnNew", "KilnNewNamespace", "KilnNewPackage", "KilnDelete", "KilnClose", "KilnInfo" }) do
  ok(cmd_exists(name), "comando :" .. name .. " registrado")
end
-- guard de migracion: los comandos antiguos ya no deben existir (corte limpio)
for _, name in ipairs({ "DotnetForge", "DotnetForgeNew", "DotnetForgeNewNamespace", "DotnetForgeNewPackage", "DotnetForgeDelete", "DotnetForgeClose", "DotnetProjectInfo", "DotnetNewProject", "CSharpForge" }) do
  ok(not cmd_exists(name), "comando antiguo :" .. name .. " eliminado")
end
local completions = vim.fn.getcompletion("KilnNew ", "cmdline")
ok(#completions >= 11, "KilnNew completa los 11 tipos de artefacto (" .. #completions .. ")")

local tmp = vim.fs.joinpath(vim.uv.os_tmpdir(), "opencode", "kiln_test_" .. os.time())
local utils = require("kiln.utils")
local console_gen = require("kiln.generators.console")
local webapi_gen = require("kiln.generators.webapi")
utils.recents_path = vim.fs.joinpath(tmp, "recents.txt")

local function mkproject(opts)
  opts = opts or {}
  return {
    name = opts.name or "Demo",
    location = tmp,
    namespace = opts.namespace or "Demo",
    framework = opts.framework or "net8.0",
    template = opts.template or "console",
    webapi = opts.webapi or { efcore=false, swagger=true, auth=false },
    features = {
      git = opts.git == true,
      sample_code = opts.sample_code ~= false,
      tests = opts.tests ~= false,
      meta_files = opts.meta_files == true,
      multi_project = opts.multi_project == true,
      docker = opts.docker == true,
    },
  }
end

utils.ensure_dir(tmp)

-- console generate
local root_c = vim.fs.joinpath(tmp, "console")
eq(console_gen.generate(mkproject({}), root_c), true, "console.generate ok")
ok(isdir(root_c), "console crea dir")
eq(vim.fn.filereadable(vim.fs.joinpath(root_c, "Demo.csproj")), 1, "console escribe csproj")
local csproj = utils.read_file(vim.fs.joinpath(root_c, "Demo.csproj")) or ""
ok(csproj:find("<TargetFramework>net8.0</TargetFramework>") ~= nil, "csproj contiene TFM")
ok(csproj:find("<RootNamespace>Demo</RootNamespace>") ~= nil, "csproj RootNamespace")

-- webapi generate
local root_w = vim.fs.joinpath(tmp, "webapi")
local pw = mkproject({ template="webapi", webapi={ swagger=true, efcore=true } })
webapi_gen.generate(pw, root_w)
eq(vim.fn.filereadable(vim.fs.joinpath(root_w, "Demo.csproj")), 1, "webapi escribe csproj")
local wcs = utils.read_file(vim.fs.joinpath(root_w, "Demo.csproj")) or ""
ok(wcs:find("Swashbuckle") ~= nil, "webapi incluye Swagger")
ok(wcs:find("EntityFrameworkCore") ~= nil, "webapi incluye EFCore")
eq(vim.fn.filereadable(vim.fs.joinpath(root_w, "Program.cs")), 1, "webapi Program.cs")
eq(vim.fn.filereadable(vim.fs.joinpath(root_w, "appsettings.json")), 1, "webapi appsettings.json")

-- validator
local validator = require("kiln.core.validator")
local valid_empty = validator.validate_project({ name="", location="", namespace="", framework="net8.0", template="console" })
ok(valid_empty == false, "validator rechaza vacio")
local valid_ok = validator.validate_project({ name="MyApp", location="/tmp", namespace="MyApp", framework="net8.0", template="console" })
ok(valid_ok == true, "validator acepta proyecto valido")
local valid_sln = validator.validate_project({ name="MySln", location="/tmp", namespace="", framework="", template="sln" })
ok(valid_sln == true, "validator acepta sln sin namespace")

-- multiproject
local mp = require("kiln.generators.multiproject")
local root_mp = vim.fs.joinpath(tmp, "mp")
local pmp = mkproject({ template="console", multi_project=true })
pmp.name = "MultiDemo"
pmp.namespace = "MultiDemo"
eq(mp.generate(pmp, root_mp), true, "multiproject generate ok")
ok(vim.fn.filereadable(vim.fs.joinpath(root_mp, "MultiDemo.sln"))==1, "multiproject sln")
ok(vim.fn.filereadable(vim.fs.joinpath(root_mp, "src/Core/Core.csproj"))==1, "multiproject Core csproj")
ok(vim.fn.filereadable(vim.fs.joinpath(root_mp, "src/App/App.csproj"))==1, "multiproject App csproj")
local mp_readme = utils.read_file(vim.fs.joinpath(root_mp, "README.md")) or ""
ok(mp_readme:find("Kiln.nvim", 1, true) ~= nil, "README generado menciona Kiln.nvim")

-- salida generada con identidad nueva
local root_wpf = vim.fs.joinpath(tmp, "wpf")
require("kiln.generators.wpf").generate(mkproject({ template = "wpf" }), root_wpf)
local xaml = utils.read_file(vim.fs.joinpath(root_wpf, "MainWindow.xaml")) or ""
ok(xaml:find('Title="Kiln"', 1, true) ~= nil, "WPF generado usa el nombre Kiln")

-- scaffold
local scaffold = require("kiln.core.scaffold")
local kinds = require("kiln.scaffold.kinds")
ok(kinds.is_valid("class"), "kinds valid")
local templ = require("kiln.scaffold.templates")
local content = templ.render("class", "Demo", "MyClass", {})
ok(content:find("class MyClass") ~= nil, "template class")

-- catalogo de plantillas
local catalog = require("kiln.catalog")
eq(#catalog.TEMPLATES, 18, "catalogo expone 18 plantillas")
ok(catalog.BY_KEY["console"] ~= nil, "plantilla console descubrible")
ok(catalog.BY_KEY["webapi"] ~= nil, "plantilla webapi descubrible")
eq(#vim.tbl_keys(kinds.BY_KEY), 11, "11 tipos de artefacto disponibles")

-- flujo principal: crear un artefacto (lo que hace :KilnNew)
local root_s = vim.fs.joinpath(tmp, "scaffold")
utils.ensure_dir(root_s)
utils.write_file(
  vim.fs.joinpath(root_s, "Demo.csproj"),
  "<Project><PropertyGroup><RootNamespace>Demo</RootNamespace></PropertyGroup></Project>"
)
local created, created_path = scaffold.create({ kind = "class", name = "Hello", pkg = "Demo", root = root_s })
ok(created == true, "scaffold.create genera artefacto: " .. tostring(created_path))
local hello_path = vim.fs.joinpath(root_s, "Hello.cs")
eq(vim.fn.filereadable(hello_path), 1, "scaffold.create escribe Hello.cs")
local hello = utils.read_file(hello_path) or ""
ok(hello:find("namespace Demo;") ~= nil, "artefacto generado usa namespace")
ok(hello:find("class Hello") ~= nil, "artefacto generado contiene class Hello")

-- keymaps del wizard
local buf = vim.api.nvim_create_buf(false, true)
require("kiln.mappings").setup(buf)
local maps = vim.api.nvim_buf_get_keymap(buf, "n")
local by_lhs = {}
for _, m in ipairs(maps) do by_lhs[m.lhs] = m.desc end
eq(by_lhs["q"], "Kiln: cerrar el asistente", "keymap q describe Kiln")
eq(by_lhs["<Esc>"], "Kiln: cerrar el asistente", "keymap <Esc> describe Kiln")
vim.api.nvim_buf_delete(buf, { force = true })

-- state sync
local st = require("kiln.state")
st.setup({})
st.reset()
st.update({ name="My App" })
require("kiln.ui.actions").sync_defaults()
eq(st.get().namespace, "MyApp", "namespace deriva de name")

-- health
local health = require("kiln.health")
ok(type(health.check)=="function", "health.check existe")
local h_ok = pcall(health.check)
ok(h_ok, "health check no falla")

if failures>0 then print(string.format("%d fallos", failures)) vim.cmd("cquit 1") else print("Todo ok") vim.cmd("qall!") end
