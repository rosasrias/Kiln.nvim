-- lua/kiln/generators/console.lua

local utils = require("kiln.utils")
local extras = require("kiln.generators.extras")

local M = {}

local function csproj_content(project)
  local tfm = project.framework or utils.get_latest_framework()
  local exclude = ""
  if project.features and project.features.tests then
    exclude = string.format([[
  <ItemGroup>
    <Compile Remove="%s.Tests\**\*" />
  </ItemGroup>
]], project.name)
  end
  return string.format([[
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>%s</RootNamespace>
  </PropertyGroup>
%s
</Project>
]], tfm, project.namespace, exclude)
end

local function program_cs(project)
  return string.format([[
namespace %s;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("Hello, World!");
    }
}
]], project.namespace)
end

local function program_test(project)
  return string.format([[
using Xunit;

namespace %s.Tests;

public class ProgramTests
{
    [Fact]
    public void SampleTest()
    {
        Assert.Equal("Hello, World!", "Hello, World!");
    }
}
]], project.namespace)
end

local function test_csproj_content(project, tfm_str)
  return string.format([[
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
end

function M.generate(project, root)
  utils.ensure_dir(root)
  utils.write_file(vim.fs.joinpath(root, project.name .. ".csproj"), csproj_content(project))

  if project.features.sample_code then
    utils.write_file(vim.fs.joinpath(root, "Program.cs"), program_cs(project))
  end

  if project.features.tests then
    -- Generar proyecto de tests separado: MyApp.Tests/MyApp.Tests.csproj (estándar .NET, evita CS0246 en proyecto Exe)
    local tfm_str = project.framework or utils.get_latest_framework()
    local test_name = project.name .. ".Tests"
    local test_dir = vim.fs.joinpath(root, test_name)
    utils.ensure_dir(test_dir)
    utils.write_file(vim.fs.joinpath(test_dir, test_name .. ".csproj"), test_csproj_content(project, tfm_str))
    utils.write_file(vim.fs.joinpath(test_dir, "ProgramTests.cs"), program_test(project))
    -- Evitar dejar artefacto roto previo: si existe ProgramTests.cs huérfano en root (bug anterior), eliminarlo
    local orphan = vim.fs.joinpath(root, "ProgramTests.cs")
    if vim.fn.filereadable(orphan) == 1 then
      local content = utils.read_file(orphan) or ""
      -- solo borrar si es el stub generado (contiene [Fact] sin using Xunit)
      if content:find("%[Fact%]") then
        vim.fn.delete(orphan)
      end
    end
  end

  extras.apply(project, root)
  return true
end

return M
