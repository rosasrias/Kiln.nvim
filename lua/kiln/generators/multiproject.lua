-- lua/kiln/generators/multiproject.lua
-- Multi-project solution: src/Core + src/App + .sln  (analogous to java multi-module)

local utils = require("kiln.utils")
local extras = require("kiln.generators.extras")
local docker = require("kiln.generators.docker")

local M = {}

M.MODULES = { "Core", "App" }

local function tfm(project)
  return project.framework or utils.get_latest_framework()
end

local function gen_dirs(project, root)
  utils.ensure_dir(vim.fs.joinpath(root, "src", "Core"))
  utils.ensure_dir(vim.fs.joinpath(root, "src", "App"))
  if project.features.tests then
    utils.ensure_dir(vim.fs.joinpath(root, "tests", "Core.Tests"))
    utils.ensure_dir(vim.fs.joinpath(root, "tests", "App.Tests"))
  end
end

local function gen_sln(project, root)
  local name = project.name
  local guid_sln = "{11111111-1111-1111-1111-111111111111}"
  local guid_core = "{22222222-2222-2222-2222-222222222222}"
  local guid_app = "{33333333-3333-3333-3333-333333333333}"
  local guid_core_tests = "{44444444-4444-4444-4444-444444444444}"
  local guid_app_tests = "{55555555-5555-5555-5555-555555555555}"
  if not project.features.tests then
    local content = string.format([[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("%s") = "Core", "src\Core\Core.csproj", "%s"
EndProject
Project("%s") = "App", "src\App\App.csproj", "%s"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
EndGlobal
]], guid_sln, guid_core, guid_sln, guid_app, guid_core, guid_core, guid_core, guid_core, guid_app, guid_app, guid_app, guid_app)
    utils.write_file(vim.fs.joinpath(root, name .. ".sln"), content)
    return
  end
  -- Con tests: incluir Core.Tests y App.Tests
  local content = string.format([[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("%s") = "Core", "src\Core\Core.csproj", "%s"
EndProject
Project("%s") = "App", "src\App\App.csproj", "%s"
EndProject
Project("%s") = "Core.Tests", "tests\Core.Tests\Core.Tests.csproj", "%s"
EndProject
Project("%s") = "App.Tests", "tests\App.Tests\App.Tests.csproj", "%s"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
		%s.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		%s.Debug|Any CPU.Build.0 = Debug|Any CPU
		%s.Release|Any CPU.ActiveCfg = Release|Any CPU
		%s.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
EndGlobal
]], guid_sln, guid_core, guid_sln, guid_app, guid_sln, guid_core_tests, guid_sln, guid_app_tests,
       guid_core, guid_core, guid_core, guid_core,
       guid_app, guid_app, guid_app, guid_app,
       guid_core_tests, guid_core_tests, guid_core_tests, guid_core_tests,
       guid_app_tests, guid_app_tests, guid_app_tests, guid_app_tests)
  utils.write_file(vim.fs.joinpath(root, name .. ".sln"), content)
end

local function core_csproj(project)
  return string.format([[
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>%s.Core</RootNamespace>
  </PropertyGroup>

</Project>
]], tfm(project), project.namespace)
end

local function app_csproj(project)
  local is_web = project.template == "webapi"
  local sdk = is_web and "Microsoft.NET.Sdk.Web" or "Microsoft.NET.Sdk"
  local extra = ""
  if is_web then
    extra = [[
  <ItemGroup>
    <ProjectReference Include="..\Core\Core.csproj" />
  </ItemGroup>
]]
  else
    extra = [[
  <ItemGroup>
    <ProjectReference Include="..\Core\Core.csproj" />
  </ItemGroup>
]]
  end
  return string.format([[
<Project Sdk="%s">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>%s</RootNamespace>
  </PropertyGroup>

%s</Project>
]], sdk, tfm(project), project.namespace, extra)
end

local function greeting_service(project)
  return string.format([[
namespace %s.Core;

public class GreetingService
{
    public string Greet() => "Hello, World!";
}
]], project.namespace)
end

local function app_program(project)
  if project.template == "webapi" then
    return string.format([[
using %s.Core;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddSingleton<GreetingService>();
var app = builder.Build();
app.MapGet("/", (GreetingService g) => g.Greet());
app.Run();
]], project.namespace)
  end
  if project.template == "wpf" then
    return string.format([[
using System.Windows;
using %s.Core;

namespace %s;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        var svc = new GreetingService();
        MessageBox.Show(svc.Greet());
    }
}
]], project.namespace, project.namespace)
  end
  return string.format([[
using %s.Core;

Console.WriteLine(new GreetingService().Greet());
]], project.namespace)
end

local function test_csproj(project, ns_suffix, ref_include)
  local tfm_str = tfm(project)
  return string.format([[
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
    <RootNamespace>%s.%s</RootNamespace>
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
    <ProjectReference Include="%s" />
  </ItemGroup>

</Project>
]], tfm_str, project.namespace, ns_suffix, ref_include)
end

local function gen_sources(project, root)
  if not project.features.sample_code then return end
  utils.write_file(vim.fs.joinpath(root, "src", "Core", "GreetingService.cs"), greeting_service(project))
  utils.write_file(vim.fs.joinpath(root, "src", "App", "Program.cs"), app_program(project))
  if project.features.tests then
    -- Core.Tests con using Xunit correcto (fix CS0246)
    utils.write_file(vim.fs.joinpath(root, "tests", "Core.Tests", "GreetingServiceTests.cs"), string.format([[
using %s.Core;
using Xunit;

namespace %s.Core.Tests;

public class GreetingServiceTests
{
    [Fact]
    public void Greets() => Assert.Equal("Hello, World!", new GreetingService().Greet());
}
]], project.namespace, project.namespace))
    utils.write_file(vim.fs.joinpath(root, "tests", "Core.Tests", "Core.Tests.csproj"), test_csproj(project, "Core.Tests", [[..\..\src\Core\Core.csproj]]))
    -- App.Tests (opcional, stub básico)
    utils.write_file(vim.fs.joinpath(root, "tests", "App.Tests", "AppTests.cs"), string.format([[
using Xunit;

namespace %s.App.Tests;

public class AppTests
{
    [Fact]
    public void Sample() => Assert.True(true);
}
]], project.namespace))
    utils.write_file(vim.fs.joinpath(root, "tests", "App.Tests", "App.Tests.csproj"), test_csproj(project, "App.Tests", [[..\..\src\App\App.csproj]]))
  end
end

local function gen_readme(project, root)
  local content = string.format([[
# %s

.NET multi-project solution generated by Kiln.nvim.

## Structure

- `src/Core` – shared library (`%s.Core.GreetingService`)
- `src/App` – executable application

## Run

```bash
dotnet run --project src/App
dotnet test
```
]], project.name, project.namespace)
  utils.write_file(vim.fs.joinpath(root, "README.md"), content)
end

function M.generate(project, root)
  gen_dirs(project, root)
  gen_sln(project, root)
  utils.write_file(vim.fs.joinpath(root, "src", "Core", "Core.csproj"), core_csproj(project))
  utils.write_file(vim.fs.joinpath(root, "src", "App", "App.csproj"), app_csproj(project))
  gen_sources(project, root)
  extras.apply(project, root)
  if project.features.docker and project.template == "webapi" then
    docker.apply(project, root, {
      dll_name = "App.dll",
      build_cmds = {
        "COPY " .. project.name .. ".sln ./",
        "COPY src/Core/Core.csproj src/Core/",
        "COPY src/App/App.csproj src/App/",
        "RUN dotnet restore",
        "",
        "COPY . ./",
        "RUN dotnet publish src/App/App.csproj -c Release -o /app/publish --no-restore",
      },
    })
  end
  gen_readme(project, root)
  return true
end

return M
