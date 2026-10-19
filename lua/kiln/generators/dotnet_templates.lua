-- lua/kiln/generators/dotnet_templates.lua
-- Contenido genérico para todas las plantillas .NET agrupadas.
-- Usa NuGet, no Maven.

local utils = require("kiln.utils")
local extras = require("kiln.generators.extras")
local docker = require("kiln.generators.docker")

local M = {}

local function tfm(project)
  local t = project.framework or utils.get_latest_framework()
  -- WPF/WinForms requieren -windows
  if (project.template == "wpf" or project.template == "wpf-lib" or project.template == "winforms" or project.template == "winforms-lib") then
    if not t:match("-windows") then t = t .. "-windows" end
  end
  return t
end

local function write_csproj(project, root, sdk, extra_props, extra_items)
  local content = string.format([[
<Project Sdk="%s">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>%s</RootNamespace>
%s
  </PropertyGroup>

%s
</Project>
]], sdk, tfm(project), project.namespace, extra_props or "", extra_items or "")
  utils.write_file(vim.fs.joinpath(root, project.name .. ".csproj"), content)
end

-- Helpers de archivos

local function console_program(ns) return string.format([[
namespace %s;

class Program
{
    static void Main(string[] args) => Console.WriteLine("Hello, World!");
}
]], ns) end

local function classlib_class(ns) return string.format([[
namespace %s;

public class Class1
{
    public string Greet() => "Hello from %s";
}
]], ns, ns) end

local function worker_program(ns) return string.format([[
using %s;

var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddHostedService<Worker>();
var host = builder.Build();
host.Run();
]], ns) end

local function worker_class(ns) return string.format([[
namespace %s;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    public Worker(ILogger<Worker> logger) => _logger = logger;
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("Worker running at: {time}", DateTimeOffset.Now);
            await Task.Delay(1000, stoppingToken);
        }
    }
}
]], ns) end

local function mvc_controller(ns) return string.format([[
using Microsoft.AspNetCore.Mvc;

namespace %s.Controllers;

public class HomeController : Controller
{
    public IActionResult Index() => View();
    public IActionResult Privacy() => View();
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() => View();
}
]], ns) end

local function mvc_program(ns) return string.format([[
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllersWithViews();
var app = builder.Build();
if (!app.Environment.IsDevelopment()) { app.UseExceptionHandler("/Home/Error"); app.UseHsts(); }
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapControllerRoute(name: "default", pattern: "{controller=Home}/{action=Index}/{id?}");
app.Run();
]], ns) end

local function razor_program(ns) return string.format([[
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorPages();
var app = builder.Build();
if (!app.Environment.IsDevelopment()) { app.UseExceptionHandler("/Error"); app.UseHsts(); }
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
]], ns) end

local function blazor_program(ns) return string.format([[
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorComponents().AddInteractiveServerComponents();
var app = builder.Build();
if (!app.Environment.IsDevelopment()) { app.UseExceptionHandler("/Error", createScopeForErrors: true); app.UseHsts(); }
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseAntiforgery();
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
app.Run();
]], ns) end

local function grpc_program(ns) return string.format([[
using %s.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddGrpc();
var app = builder.Build();
app.MapGrpcService<GreeterService>();
app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client.");
app.Run();
]], ns) end

local function grpc_service(ns) return string.format([[
using Grpc.Core;

namespace %s.Services;

public class GreeterService : Greeter.GreeterBase
{
    public override Task<HelloReply> SayHello(HelloRequest request, ServerCallContext context) =>
        Task.FromResult(new HelloReply { Message = "Hello " + request.Name });
}
]], ns) end

local function testing_project(sdk, tfm_str, ns, pkg_block)
  return string.format([[
<Project Sdk="%s">

  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <RootNamespace>%s</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
%s
  </ItemGroup>

</Project>
]], sdk, tfm_str, ns, pkg_block)
end

-- Public: genera cualquier template

function M.generate(project, root)
  local tpl = project.template
  local ns = project.namespace
  local name = project.name

  utils.ensure_dir(root)

  if tpl == "console" then
    write_csproj(project, root, "Microsoft.NET.Sdk", "    <OutputType>Exe</OutputType>")
    if project.features.sample_code then utils.write_file(vim.fs.joinpath(root, "Program.cs"), console_program(ns)) end

  elseif tpl == "classlib" then
    write_csproj(project, root, "Microsoft.NET.Sdk", "")
    if project.features.sample_code then utils.write_file(vim.fs.joinpath(root, "Class1.cs"), classlib_class(ns)) end

  elseif tpl == "worker" then
    local hosting_ver = utils.framework_package_version(tfm(project), "10.0.0")
    write_csproj(project, root, "Microsoft.NET.Sdk.Worker", "", string.format([[  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="%s" />
  </ItemGroup>]], hosting_ver))
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), worker_program(ns))
      utils.write_file(vim.fs.joinpath(root, "Worker.cs"), worker_class(ns))
      utils.write_file(vim.fs.joinpath(root, "appsettings.json"), string.format([[
{
  "Logging": { "LogLevel": { "Default": "Information" } }
}
]], name))
    end

  elseif tpl == "webapi" then
    -- delegado a webapi.lua para mantener Swagger/EF logic
    return require("kiln.generators.webapi").generate(project, root)

  elseif tpl == "mvc" then
    write_csproj(project, root, "Microsoft.NET.Sdk.Web", "")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), mvc_program(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Controllers"))
      utils.write_file(vim.fs.joinpath(root, "Controllers", "HomeController.cs"), mvc_controller(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Views", "Home"))
      utils.write_file(vim.fs.joinpath(root, "Views", "Home", "Index.cshtml"), [[
@{
    ViewData["Title"] = "Home Page";
}
<div class="text-center">
    <h1 class="display-4">Welcome</h1>
    <p>Learn about <a href="https://learn.microsoft.com/aspnet/core">building Web apps with ASP.NET Core</a>.</p>
</div>
]])
      utils.ensure_dir(vim.fs.joinpath(root, "Models"))
      utils.write_file(vim.fs.joinpath(root, "Models", "ErrorViewModel.cs"), string.format([[
namespace %s.Models;
public class ErrorViewModel { public string? RequestId { get; set; } public bool ShowRequestId => !string.IsNullOrEmpty(RequestId); }
]], ns))
      utils.write_file(vim.fs.joinpath(root, "appsettings.json"), string.format([[{"ApplicationName":"%s"}]], name))
    end

  elseif tpl == "razor" then
    write_csproj(project, root, "Microsoft.NET.Sdk.Web", "")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), razor_program(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Pages"))
      utils.write_file(vim.fs.joinpath(root, "Pages", "Index.cshtml"), [[
@page
@model IndexModel
@{
    ViewData["Title"] = "Home page";
}
<div class="text-center">
    <h1 class="display-4">Welcome</h1>
</div>
]])
      utils.write_file(vim.fs.joinpath(root, "Pages", "Index.cshtml.cs"), string.format([[
using Microsoft.AspNetCore.Mvc.RazorPages;
namespace %s.Pages;
public class IndexModel : PageModel { public void OnGet() {} }
]], ns))
    end

  elseif tpl == "blazor" then
    write_csproj(project, root, "Microsoft.NET.Sdk.Web", "")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), blazor_program(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Components", "Pages"))
      utils.write_file(vim.fs.joinpath(root, "Components", "App.razor"), [[
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"/><title>Blazor</title></head>
<body><Routes/></body>
</html>
]])
    end

  elseif tpl == "blazorwasm" then
    write_csproj(project, root, "Microsoft.NET.Sdk.BlazorWebAssembly", "")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), string.format([[
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using %s;
var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");
builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });
await builder.Build().RunAsync();
]], ns))
      utils.write_file(vim.fs.joinpath(root, "App.razor"), [[
<Router AppAssembly="@typeof(App).Assembly">
    <Found Context="routeData"><RouteView RouteData="@routeData"/></Found>
    <NotFound><p>Not found</p></NotFound>
</Router>
]])
    end

  elseif tpl == "empty" then
    write_csproj(project, root, "Microsoft.NET.Sdk.Web", "")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), [[
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.MapGet("/", () => "Hello World!");
app.Run();
]])
    end

  elseif tpl == "grpc" then
    write_csproj(project, root, "Microsoft.NET.Sdk.Web", "", [[  <ItemGroup>
    <PackageReference Include="Grpc.AspNetCore" Version="2.60.0" />
    <PackageReference Include="Google.Protobuf" Version="3.25.0" />
    <PackageReference Include="Grpc.Tools" Version="2.60.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
  </ItemGroup>

  <ItemGroup>
    <Protobuf Include="Protos\greet.proto" GrpcServices="Server" />
  </ItemGroup>]])
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), grpc_program(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Services"))
      utils.write_file(vim.fs.joinpath(root, "Services", "GreeterService.cs"), grpc_service(ns))
      utils.ensure_dir(vim.fs.joinpath(root, "Protos"))
      utils.write_file(vim.fs.joinpath(root, "Protos", "greet.proto"), [[
syntax = "proto3";
option csharp_namespace = "Greeter";
package greet;
service Greeter { rpc SayHello (HelloRequest) returns (HelloReply); }
message HelloRequest { string name = 1; }
message HelloReply { string message = 1; }
]])
    end

  elseif tpl == "wpf" then
    return require("kiln.generators.wpf").generate(project, root)

  elseif tpl == "wpf-lib" then
    write_csproj(project, root, "Microsoft.NET.Sdk", "    <UseWPF>true</UseWPF>")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "CustomControl.cs"), string.format([[
using System.Windows.Controls;
namespace %s;
public class CustomControl : Control { }
]], ns))
    end

  elseif tpl == "winforms" then
    write_csproj(project, root, "Microsoft.NET.Sdk", "    <UseWindowsForms>true</UseWindowsForms>\n    <OutputType>WinExe</OutputType>")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "Program.cs"), string.format([[
namespace %s;
static class Program
{
    [STAThread]
    static void Main() { ApplicationConfiguration.Initialize(); Application.Run(new Form1()); }
}
]], ns))
      utils.write_file(vim.fs.joinpath(root, "Form1.cs"), string.format([[
namespace %s;
public partial class Form1 : Form { public Form1() { InitializeComponent(); Text = "Hello WinForms"; } }
]], ns))
      utils.write_file(vim.fs.joinpath(root, "Form1.Designer.cs"), [[
partial class Form1 { private System.ComponentModel.IContainer components = null; private void InitializeComponent() { this.SuspendLayout(); this.ClientSize = new System.Drawing.Size(800, 450); this.ResumeLayout(false); } }
]])
    end

  elseif tpl == "winforms-lib" then
    write_csproj(project, root, "Microsoft.NET.Sdk", "    <UseWindowsForms>true</UseWindowsForms>")
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "CustomControl.cs"), string.format([[
using System.Windows.Forms;
namespace %s;
public class CustomControl : Control { }
]], ns))
    end

  elseif tpl == "xunit" then
    local tfm_str = tfm(project)
    utils.write_file(vim.fs.joinpath(root, name .. ".csproj"), testing_project("Microsoft.NET.Sdk", tfm_str, ns, [[    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="xunit" Version="2.7.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.4">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
    <PackageReference Include="coverlet.collector" Version="6.0.0">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>]]))
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "UnitTest1.cs"), string.format([[
using Xunit;
namespace %s;
public class UnitTest1 { [Fact] public void Test1() => Assert.True(true); }
]], ns))
    end

  elseif tpl == "nunit" then
    local tfm_str = tfm(project)
    utils.write_file(vim.fs.joinpath(root, name .. ".csproj"), testing_project("Microsoft.NET.Sdk", tfm_str, ns, [[    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="NUnit" Version="4.1.0" />
    <PackageReference Include="NUnit3TestAdapter" Version="4.5.0" />
    <PackageReference Include="NUnit.Analyzers" Version="4.2.0" />]]))
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "UnitTest1.cs"), string.format([[
using NUnit.Framework;
namespace %s;
public class Tests { [SetUp] public void Setup() {} [Test] public void Test1() => Assert.Pass(); }
]], ns))
    end

  elseif tpl == "mstest" then
    local tfm_str = tfm(project)
    utils.write_file(vim.fs.joinpath(root, name .. ".csproj"), testing_project("Microsoft.NET.Sdk", tfm_str, ns, [[    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="MSTest.TestAdapter" Version="3.1.1" />
    <PackageReference Include="MSTest.TestFramework" Version="3.1.1" />
    <PackageReference Include="coverlet.collector" Version="6.0.0">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>]]))
    if project.features.sample_code then
      utils.write_file(vim.fs.joinpath(root, "UnitTest1.cs"), string.format([[
using Microsoft.VisualStudio.TestTools.UnitTesting;
namespace %s;
[TestClass] public class UnitTest1 { [TestMethod] public void TestMethod1() {} }
]], ns))
    end

  elseif tpl == "sln" then
    -- Blank solution: solo .sln
    local sln_content = string.format([[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
Global
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
]], name)
    utils.write_file(vim.fs.joinpath(root, name .. ".sln"), sln_content)
    -- no csproj
  else
    -- fallback console
    write_csproj(project, root, "Microsoft.NET.Sdk", "    <OutputType>Exe</OutputType>")
    if project.features.sample_code then utils.write_file(vim.fs.joinpath(root, "Program.cs"), console_program(ns)) end
  end

  -- Docker solo para webs
  if project.features.docker and M.is_web_docker(tpl) then
    docker.apply(project, root)
  end

  extras.apply(project, root)
  return true
end

function M.is_web_docker(tpl)
  return tpl == "webapi" or tpl == "mvc" or tpl == "razor" or tpl == "blazor" or tpl == "blazorwasm" or tpl == "empty" or tpl == "grpc"
end

return M
