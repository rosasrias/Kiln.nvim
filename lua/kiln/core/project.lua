-- lua/kiln/core/project.lua

local utils = require("kiln.utils")
local validator = require("kiln.core.validator")
local generators = require("kiln.generators")
local state = require("kiln.state")

local M = {}

function M.main_class_source(project, opts)
  opts = opts or {}
  local ns = project.namespace
  if project.template == "webapi" then
    return string.format([[
using Microsoft.AspNetCore.Mvc;

namespace %s.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HelloController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok("Hello, World!");
}
]], ns), "HelloController.cs"
  end
  if project.template == "wpf" then
    return string.format([[
using System.Windows;

namespace %s;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }
}
]], ns), "MainWindow.xaml.cs"
  end
  if opts.use_core_greeting then
    return string.format([[
using %s.Core;

namespace %s;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine(new GreetingService().Greet());
    }
}
]], ns, ns), "Program.cs"
  end
  return string.format([[
namespace %s;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("Hello, World!");
    }
}
]], ns), "Program.cs"
end

function M.test_source(project, kind)
  local ns = project.namespace
  if kind == "core" then
    return string.format([[
using %s.Core;
using Xunit;

public class GreetingServiceTests
{
    [Fact]
    public void Greets() => Assert.Equal("Hello, World!", new GreetingService().Greet());
}
]], ns), vim.fs.joinpath("src", "Core", "GreetingServiceTests.cs")
  end
  if project.template == "webapi" then
    return string.format([[
using Xunit;

namespace %s.Tests;

public class HelloControllerTests
{
    [Fact]
    public void Get_ReturnsOk() => Assert.True(true);
}
]], ns), vim.fs.joinpath("HelloControllerTests.cs")
  end
  if project.template == "wpf" then return nil end
  if kind ~= "app" then return nil end
  return string.format([[
using Xunit;

namespace %s.Tests;

public class ProgramTests
{
    [Fact]
    public void Sample() => Assert.Equal("Hello, World!", "Hello, World!");
}
]], ns), vim.fs.joinpath("ProgramTests.cs")
end

local function generate_main(project, root)
  if not project.features.sample_code then return end
  local catalog = require("kiln.catalog")
  if catalog.is_testing(project.template) or project.template == "sln" then return end
  local source, file_name = M.main_class_source(project)
  -- generators already create Program; this is fallback for single project custom flow
  if file_name == "Program.cs" then
    local p = vim.fs.joinpath(root, file_name)
    if vim.fn.filereadable(p) == 0 then utils.write_file(p, source) end
  end
end

local function generate_test(project, root)
  if not project.features.tests or not project.features.sample_code then return end
  -- No generar stub adicional si el template ya ES un proyecto de testing (xunit/nunit/mstest)
  local catalog = require("kiln.catalog")
  if catalog.is_testing(project.template) then return end
  if project.template == "sln" then return end
  -- Si el generador dedicado (console) ya creó un proyecto de tests separado, no duplicar ProgramTests.cs en root
  -- Genérico: si ya existe carpeta Tests con csproj, no duplicar
  do
    local existing_test_proj = vim.fs.joinpath(root, project.name .. ".Tests", project.name .. ".Tests.csproj")
    if vim.fn.filereadable(existing_test_proj) == 1 then return end
    local has_any_test_cs = vim.fn.filereadable(vim.fs.joinpath(root, project.name .. ".Tests", "ProgramTests.cs")) == 1
        or vim.fn.filereadable(vim.fs.joinpath(root, project.name .. ".Tests", "HelloControllerTests.cs")) == 1
    if has_any_test_cs then return end
  end
  local source, rel = M.test_source(project, "app")
  if not source then return end
  -- Evitar generar test dentro del proyecto principal (provoca CS0246: Fact no encontrado)
  -- Cualquier stub con [Fact]/[Test]/[TestMethod] debe ir a proyecto Tests separado
  local has_test_attr = source:find("%[Fact%]") or source:find("%[Test%]") or source:find("%[TestMethod%]")
  if has_test_attr and not rel:find("%.Tests") then
    -- Redirigir a proyecto separado MyApp.Tests para TODAS las plantillas de app (console, webapi, mvc, razor, blazor, etc)
    local test_name = project.name .. ".Tests"
    local test_dir = vim.fs.joinpath(root, test_name)
    utils.ensure_dir(test_dir)
    local tfm_str = project.framework or utils.get_latest_framework()
    local csproj = string.format([[
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
    <RootNamespace>%s.Tests</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="xunit" Version="2.7.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.4">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
    <PackageReference Include="coverlet.collector" Version="6.0.0">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\%s.csproj" />
  </ItemGroup>

</Project>
]], tfm_str, project.namespace, project.name)
    utils.write_file(vim.fs.joinpath(test_dir, test_name .. ".csproj"), csproj)
    local test_file = vim.fs.basename(rel)
    utils.write_file(vim.fs.joinpath(test_dir, test_file), source)
    -- Limpiar huérfano previo en root (bug previo CS0246)
    local orphan = vim.fs.joinpath(root, test_file)
    if vim.fn.filereadable(orphan) == 1 and orphan ~= vim.fs.joinpath(test_dir, test_file) then
      pcall(vim.fn.delete, orphan)
    end
    -- También limpiar genérico ProgramTests.cs huérfano si el test era HelloControllerTests pero quedó antiguo ProgramTests
    local generic_orphan = vim.fs.joinpath(root, "ProgramTests.cs")
    if vim.fn.filereadable(generic_orphan) == 1 then
      local c = utils.read_file(generic_orphan) or ""
      if c:find("%[Fact%]") then pcall(vim.fn.delete, generic_orphan) end
    end
      -- Asegurar que el csproj principal excluya los tests anidados (evita CS0246 + CS0579 por glob recursivo)
      local main_csproj = vim.fs.joinpath(root, project.name .. ".csproj")
      local main_content = utils.read_file(main_csproj)
      if main_content and not main_content:find("Compile Remove") then
        main_content = main_content:gsub("</Project>", string.format('  <ItemGroup>\n    <Compile Remove="%s.Tests\\**\\*" />\n  </ItemGroup>\n\n</Project>', project.name))
        utils.write_file(main_csproj, main_content)
      end
      return
  end
  utils.write_file(vim.fs.joinpath(root, rel), source)
end

local function generate_readme(project, root)
  local catalog = require("kiln.catalog")
  local tpl = catalog.BY_KEY[project.template]
  local dotnet_cmd = tpl and ("dotnet new " .. tpl.dotnet) or "dotnet run"
  local cmd = "dotnet run"
  if project.template == "sln" then cmd = "dotnet sln list"
  elseif catalog.is_testing(project.template) then cmd = "dotnet test"
  end
  local readme = string.format([[
# %s

.NET project generated by Kiln.nvim — NuGet.

## Metadata

- Namespace: `%s`
- Framework: `%s`
- Template: `%s` (%s)
- dotnet new: `%s`

## Run

```bash
%s
dotnet test
dotnet publish -c Release
```
]], project.name, project.namespace, project.framework or "-", project.template or "console", tpl and tpl.description or "", dotnet_cmd, cmd)
  utils.write_file(vim.fs.joinpath(root, "README.md"), readme)
end

local function init_git(project, root)
  if not project.features.git then return end
  if vim.fn.executable("git") ~= 1 then vim.notify("Git no está instalado; se omitió git init.", vim.log.levels.WARN) return end
  local result = vim.system({ "git", "init" }, { cwd = root, text = true }):wait()
  if result.code ~= 0 then vim.notify("git init falló.", vim.log.levels.WARN) end
end

function M.create(project)
  local ok, errors = validator.validate_project(project)
  if not ok then vim.notify("Kiln: proyecto inválido\n\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR) return false end
  local base_dir = vim.fn.expand(project.location)
  local root = vim.fs.joinpath(base_dir, project.name)
  if vim.uv.fs_stat(root) then
    local files = vim.fn.readdir(root)
    if #files > 0 then vim.notify("El directorio ya existe y no está vacío:\n" .. root, vim.log.levels.ERROR) return false end
  end
  utils.ensure_dir(root)

  if project.features.multi_project then
    local mp = require("kiln.generators.multiproject")
    local generated, err = mp.generate(project, root)
    if not generated then vim.notify(err or "No se pudo generar el proyecto multi-project.", vim.log.levels.ERROR) return false end
    init_git(project, root)
    vim.notify("Kiln: proyecto creado:\n" .. root, vim.log.levels.INFO)
    return true, root
  end

  local generated, err = generators.generate(project, root)
  if not generated then vim.notify(err or "No se pudo generar el proyecto.", vim.log.levels.ERROR) return false end
  generate_main(project, root)
  generate_test(project, root)
  generate_readme(project, root)
  init_git(project, root)
  vim.notify("Kiln: proyecto creado:\n" .. root, vim.log.levels.INFO)
  return true, root
end

return M
