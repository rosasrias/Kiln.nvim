# Kiln.nvim

[![test](https://github.com/rosasrias/Kiln.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/rosasrias/Kiln.nvim/actions/workflows/test.yml)
![Neovim >=0.10](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim)
![.NET SDK](https://img.shields.io/badge/.NET-8%20%7C%209%20%7C%2010-512BD4?logo=dotnet)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Asistente para crear proyectos **C# / .NET** dentro de Neovim, con interfaz estilo IntelliJ IDEA sobre [volt](https://github.com/nvzone/volt).

Clon hermano de `javaforge.nvim` adaptado a .NET — **usa NuGet, no Maven** — con 18 plantillas `dotnet new` completas. Incluye wizard de proyectos y popup *New C# Class*.

<p align="center">
  <img src="assets/start.png" alt="Kiln.nvim Wizard" width="85%" />
  <br/>
  <em>Wizard — creación de proyecto .NET estilo IntelliJ</em>
</p>

---

## ✨ Características

- Wizard visual con validación en tiempo real
- 18 plantillas `dotnet new` agrupadas con sidebar por categorías
- Detección automática de SDKs (`dotnet --list-sdks`, `DOTNET_ROOT`, `C:\Program Files\dotnet\sdk`)
- Sincronización bidireccional `Name ↔ Namespace` (PascalCase)
- Scaffolding de 11 tipos de clases C#
- Soporte multi-project (`Core` + `App` + `.sln`)
- Docker integrado (`sdk → aspnet`)
- Historial de ubicaciones y `checkhealth`

## Wizard (`:KilnProject`)

- **Campos inteligentes**: Name, Location, Namespace, Framework (`net8.0` / `net9.0` / `net10.0` + `-windows` para WPF/WinForms). Namespace derivado a PascalCase con sync bidireccional.
- **Ubicación**: picker con historial `kiln_locations`.
- **SDK**: `dotnet --list-sdks` + `DOTNET_ROOT` + PATH + `C:\Program Files\dotnet\sdk` | `lua/kiln/utils.lua:124`
- **TFM**: `<TargetFramework>` + imagen Docker `mcr.microsoft.com/dotnet/sdk:8.0` → `aspnet:8.0`.

### Plantillas (18) — `lua/kiln/catalog.lua`

| Grupo | Plantilla | `dotnet new` | Genera (NuGet) |
|-------|-----------|--------------|----------------|
| 🖥️ General | **Console App** | `console` | `Microsoft.NET.Sdk` + `Program.cs` |
|  | **Class Library** | `classlib` | `Class1.cs` |
|  | **Worker Service** | `worker` | `Microsoft.Extensions.Hosting` + `Worker.cs` |
| 🌐 ASP.NET Core | **Web API** | `webapi` | `Microsoft.NET.Sdk.Web` + `Swashbuckle.AspNetCore` (chips EF Core/Swagger/Auth) |
|  | **MVC** | `mvc` | `Controllers/HomeController.cs` + `Views/Home/Index.cshtml` |
|  | **Razor Pages** | `webapp` | `Pages/Index.cshtml` |
|  | **Blazor** | `blazor` | `Components/App.razor` |
|  | **Blazor WASM** | `blazorwasm` | `Microsoft.NET.Sdk.BlazorWebAssembly` |
|  | **Empty Web** | `web` | `MapGet("/")` mínimo |
| 🔌 Servicios | **gRPC Service** | `grpc` | `Grpc.AspNetCore` + `Protos/greet.proto` |
| 🖼️ Desktop | **WPF App** | `wpf` | `<UseWPF>true</UseWPF>` + `App.xaml/MainWindow.xaml` |
|  | **WPF Library** | `wpflib` | `<UseWPF>true</UseWPF>` |
|  | **WinForms App** | `winforms` | `<UseWindowsForms>true</UseWindowsForms>` + `Form1.cs` |
|  | **WinForms Library** | `winformslib` | `<UseWindowsForms>true</UseWindowsForms>` |
| 🧪 Testing | **xUnit** | `xunit` | `xunit`, `Microsoft.NET.Test.Sdk`, `coverlet.collector` |
|  | **NUnit** | `nunit` | `NUnit`, `NUnit3TestAdapter` |
|  | **MSTest** | `mstest` | `MSTest.TestFramework` |
| 📦 Solución | **Solution** | `sln` | `.sln` blank |

> Todas usan `<RootNamespace>` = Namespace del wizard y `<ImplicitUsings>enable</ImplicitUsings>` + `<Nullable>enable</Nullable>`.

En Web API los **chips** `EF Core / Swagger / Auth` añaden `PackageReference` NuGet correspondientes (`lua/kiln/generators/webapi.lua:17`).

### Features

| Feature | Acción |
|---------|--------|
| Create Git repository | `git init` + `.gitignore` (`bin/ obj/ .vs/`) |
| Add sample code | Código real por plantilla (ver tabla) |
| Add tests (NuGet) | Stub `[Fact]/[Test]/[TestMethod]` |
| Add .editorconfig & .gitattributes | Meta |
| **Multi-project (Core/App) + .sln** | `src/Core/Core.csproj` + `src/App/App.csproj` + `ProjectReference` + `.sln` (`lua/kiln/generators/multiproject.lua`) |
| Add Dockerfile & docker-compose | `sdk:8.0 → aspnet:8.0` + `dotnet publish` (solo webs) |

Sidebar agrupa plantillas por categoría con iconos ( `🖥️ General | 🌐 ASP.NET Core | 🔌 Servicios | 🖼️ Desktop | 🧪 Testing | 📦 Solución` ) — `lua/kiln/ui/views/new_project.lua:112`.

### New C# Class (`:KilnNew`)

<p align="center">
  <img src="assets/class.png" alt="New C# Class popup" width="70%" />
  <br/>
  <em>Popup — New C# Class con 11 tipos</em>
</p>

11 tipos: `class/interface/record/enum/struct/exception` + `entity/controller/service/repository/worker` — namespace autodetectado vía `<RootNamespace>` + sufijos (`UserController.cs`).

### Delete (`:KilnDelete`)

Busca `*.cs` en raíces `*.csproj/ *.sln`, lista `namespace.clase [root]`, borra tests asociados.

---

## Requisitos

| Requisito | Obligatorio | Notas |
|-----------|-------------|-------|
| Neovim >=0.10 | Sí | `vim.fs.joinpath`, `vim.system` |
| [volt](https://github.com/nvzone/volt) | Sí | UI framework |
| .NET SDK 8/9/10 | Para compilar | Plugin genera sin `dotnet` instalado |
| git | Opcional | Para `Create Git repository` |

> Plugin genera sin necesidad de `dotnet` instalado.

## Instalación

### lazy.nvim

```lua
{
  "rosasrias/Kiln.nvim",
  dependencies = { "nvzone/volt" },
  opts = {
    project = {
      default_location = "~/code",
      default_namespace = "MyApp",
      default_framework = "net8.0",
      default_template = "console",
    },
    git = { enabled = true },
  },
  config = function(_, opts)
    require("kiln").setup(opts)
  end,
}
```

Reinicia Neovim y el plugin registrará los comandos automáticamente.

## Uso

El módulo público es `require("kiln")` y expone `setup()`, `open()` y `close()`.
`:KilnNew` es el comando principal para generar artefactos C# (clases, interfaces, records,
enums, structs y variantes como controller/service/repository); `:KilnProject` abre el wizard
de proyectos .NET.

```vim
:KilnProject       " wizard de creación de proyectos .NET
:KilnNew           " popup de artefactos (clase/interface/record/enum/struct/...)
:KilnNew entity    " abrir el popup con un tipo preseleccionado
:KilnNewNamespace  " crear namespace (alias :KilnNewPackage)
:KilnDelete        " eliminar clase + tests asociados
:KilnInfo          " info del proyecto .NET actual
:KilnClose         " cerrar wizard
:checkhealth kiln  " verificar SDKs y dependencias
```

### Atajos dentro del wizard

| Tecla | Acción |
|-------|--------|
| `<CR>` | Confirmar / Crear proyecto |
| `<Esc>` / `q` | Cerrar |
| `<Tab>` / `<S-Tab>` | Navegar campos |
| `<C-s>` | Guardar / Crear |

### Configuración avanzada

```lua
require("kiln").setup({
  project = {
    default_location = "~/Documents/code",
    default_namespace = "MyCompany.App",
    default_framework = "net9.0",
    default_template = "webapi",
    default_sdk = nil, -- auto-detect
  },
  git = {
    enabled = true,
  },
})
```

Namespace se deriva automáticamente de `Name` en PascalCase si no está editado manualmente (`lua/kiln/ui/actions.lua:61`).

## ¿Qué necesita .NET vs Java?

- **SDK**: `dotnet --list-sdks` → TFM `net8.0/9.0/10.0` (`<TargetFramework>`). No `pom.xml`.
- **NuGet**: `PackageReference` en `.csproj` (no `<dependency>` Maven). Cada plantilla declara sus paquetes (gRPC, xUnit, etc.).
- **Templates**: mapean 1:1 a `dotnet new` (`console`, `classlib`, `webapi`, `mvc`, `wpf`, `xunit`, `sln`…).
- **Sln**: análogo a `multi-module` Maven — `.sln` + `ProjectReference`.
- **Desktop**: requiere `-windows` TFM (`UseWPF`/`UseWindowsForms`).
- **Testing**: NuGet `Microsoft.NET.Test.Sdk` + framework (`xunit` vs `NUnit` vs `MSTest`).

## Estructura

```
lua/kiln/
  catalog.lua              catálogo 18 plantillas agrupadas
  init.lua                 comandos :Kiln*
  state.lua                estado + default_template
  utils.lua                detect_sdks() + recents
  health.lua               checkhealth kiln
  core/{detector,project,validator,scaffold}
  generators/{console,webapi,wpf,dotnet_templates,multiproject,docker,extras}
  ui/{window,input,actions,components,highlights,views/new_project}
  scaffold/{kinds,templates,ui,ui_delete}
tests/run.lua
.github/workflows/test.yml
```

## Testing

```bash
# Headless (requiere nvim + volt)
nvim --headless --clean "+set rtp^=/tmp/volt,$PWD" "+luafile tests/run.lua"

# O via GitHub Actions (ubuntu + nvim stable/nightly)
```

## Contribución

1. Fork & `git clone https://github.com/rosasrias/Kiln.nvim.git`
2. Crea branch `feat/mi-cambio`
3. `nvim --headless --clean "+luafile tests/run.lua"` debe pasar
4. PR con descripción clara


Otros cambios:

- El historial de ubicaciones pasó de `dotnetforge_locations` a `kiln_locations`; se puede borrar
  el archivo anterior sin perder funcionalidad.
- Las opciones de configuración (`project.*`, `git.*`) no cambian.
- Las keymaps del wizard se conservan tal cual (`q`, `<Esc>`, `<Tab>`, `<CR>`, `<C-s>`).

## Licencia

MIT — ver [LICENSE](LICENSE).
