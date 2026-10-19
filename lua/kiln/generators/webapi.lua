-- lua/kiln/generators/webapi.lua

local utils = require("kiln.utils")
local extras = require("kiln.generators.extras")
local docker = require("kiln.generators.docker")

local M = {}

local function csproj_content(project)
  local tfm = project.framework or utils.get_latest_framework()
  local extra_packages = {}
  if project.webapi and project.webapi.efcore then
    local ef_ver = utils.framework_package_version(tfm, "10.0.0")
    table.insert(extra_packages, '    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="' .. ef_ver .. '" />')
    table.insert(extra_packages, '    <PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="' .. ef_ver .. '" />')
  end
  if project.webapi and project.webapi.swagger then
    table.insert(extra_packages, '    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />')
  end
  local pkg_block = ""
  if #extra_packages > 0 then
    pkg_block = "  <ItemGroup>\n" .. table.concat(extra_packages, "\n") .. "\n  </ItemGroup>\n"
  end
  local exclude = ""
  if project.features and project.features.tests then
    exclude = string.format([[
  <ItemGroup>
    <Compile Remove="%s.Tests\**\*" />
  </ItemGroup>
]], project.name)
  end
  return string.format([[
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>%s</RootNamespace>
  </PropertyGroup>

%s%s</Project>
]], tfm, project.namespace, pkg_block, exclude)
end

local function program_cs(project)
  local swagger = project.webapi and project.webapi.swagger
  local sw_lines = ""
  if swagger then
    sw_lines = [[
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
]]
  end
  return string.format([[
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
%s
var app = builder.Build();
%s
app.UseAuthorization();
app.MapControllers();
app.Run();
]], swagger and "builder.Services.AddSwaggerGen();" or "", sw_lines)
end

local function controller_cs(project)
  return string.format([[
using Microsoft.AspNetCore.Mvc;

namespace %s.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HelloController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { message = "Hello, World!" });
}
]], project.namespace)
end

local function appsettings(project)
  return string.format([[
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ApplicationName": "%s"
}
]], project.name)
end

function M.generate(project, root)
  utils.ensure_dir(root)
  utils.write_file(vim.fs.joinpath(root, project.name .. ".csproj"), csproj_content(project))

  if project.features.sample_code then
    utils.write_file(vim.fs.joinpath(root, "Program.cs"), program_cs(project))
    utils.ensure_dir(vim.fs.joinpath(root, "Controllers"))
    utils.write_file(vim.fs.joinpath(root, "Controllers", "HelloController.cs"), controller_cs(project))
    utils.write_file(vim.fs.joinpath(root, "appsettings.json"), appsettings(project))
    utils.write_file(vim.fs.joinpath(root, "appsettings.Development.json"), [[
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  }
}
]])
  else
    utils.write_file(vim.fs.joinpath(root, "appsettings.json"), appsettings(project))
  end

  extras.apply(project, root)
  if project.features.docker then docker.apply(project, root) end
  return true
end

return M
