-- lua/kiln/generators/wpf.lua
-- Desktop WPF template (Windows) – analogous to javaforge javafx

local utils = require("kiln.utils")
local extras = require("kiln.generators.extras")

local M = {}

local function csproj_content(project)
  local tfm = project.framework or utils.get_latest_framework()
  -- Ensure windows suffix
  if not tfm:match("%-windows") then tfm = tfm .. "-windows" end
  return string.format([[
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>%s</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UseWPF>true</UseWPF>
    <RootNamespace>%s</RootNamespace>
  </PropertyGroup>

</Project>
]], tfm, project.namespace)
end

local function app_xaml()
  return [[
<Application x:Class="App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             StartupUri="MainWindow.xaml">
</Application>
]]
end

local function app_cs(project)
  return string.format([[
using System.Windows;

namespace %s;

public partial class App : Application
{
}
]], project.namespace)
end

local function mainwindow_xaml()
  return [[
<Window x:Class="MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Kiln" Height="450" Width="800">
    <Grid>
        <Label Content="Hello, WPF!" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24"/>
    </Grid>
</Window>
]]
end

local function mainwindow_cs(project)
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
]], project.namespace)
end

function M.generate(project, root)
  utils.ensure_dir(root)
  utils.write_file(vim.fs.joinpath(root, project.name .. ".csproj"), csproj_content(project))
  if project.features.sample_code then
    utils.write_file(vim.fs.joinpath(root, "App.xaml"), app_xaml())
    utils.write_file(vim.fs.joinpath(root, "App.xaml.cs"), app_cs(project))
    utils.write_file(vim.fs.joinpath(root, "MainWindow.xaml"), mainwindow_xaml())
    utils.write_file(vim.fs.joinpath(root, "MainWindow.xaml.cs"), mainwindow_cs(project))
  end
  extras.apply(project, root)
  return true
end

return M
