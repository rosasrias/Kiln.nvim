-- lua/kiln/generators/docker.lua

local utils = require("kiln.utils")

local M = {}

function M.dockerfile_lines(project, opts)
  opts = opts or {}
  local framework = project.framework or utils.get_latest_framework()
  local sdk_ver = framework:match("net(%d+)%.%d+") or "8"
  -- dotnet sdk images: mcr.microsoft.com/dotnet/sdk:8.0
  local lines = {}
  if opts.build_cmds then
    vim.list_extend(lines, {
      "# Build",
      "FROM mcr.microsoft.com/dotnet/sdk:" .. sdk_ver .. ".0 AS build",
      "WORKDIR /src",
      "",
    })
    vim.list_extend(lines, opts.build_cmds)
  else
    local proj = project.name or "App"
    vim.list_extend(lines, {
      "# Build",
      "FROM mcr.microsoft.com/dotnet/sdk:" .. sdk_ver .. ".0 AS build",
      "WORKDIR /src",
      "",
      "COPY *.csproj ./",
      "RUN dotnet restore",
      "",
      "COPY . ./",
      "RUN dotnet publish -c Release -o /app/publish --no-restore",
    })
  end

  vim.list_extend(lines, {
    "",
    "# Run",
    "FROM mcr.microsoft.com/dotnet/aspnet:" .. sdk_ver .. ".0 AS final",
    "WORKDIR /app",
    "",
    "COPY --from=build /app/publish .",
    "",
    "EXPOSE 8080",
    "ENV ASPNETCORE_URLS=http://+:8080",
    "",
    'ENTRYPOINT ["dotnet", "' .. (opts.dll_name or (project.name .. ".dll")) .. '"]',
    "",
  })
  return lines
end

local function compose_content(project)
  local name = utils.slug(project.name or "app")
  local lines = {
    "services:",
    "  " .. name .. ":",
    "    build: .",
    "    ports:",
    '      - "8080:8080"',
    "    environment:",
    "      - ASPNETCORE_ENVIRONMENT=Development",
    "    restart: unless-stopped",
    "",
  }
  return table.concat(lines, "\n")
end

function M.apply(project, root, opts)
  utils.write_file(vim.fs.joinpath(root, "Dockerfile"), table.concat(M.dockerfile_lines(project, opts), "\n"))
  utils.write_file(vim.fs.joinpath(root, ".dockerignore"), table.concat({
    ".git",
    "bin/",
    "obj/",
    "*.md",
    "",
  }, "\n"))
  utils.write_file(vim.fs.joinpath(root, "docker-compose.yml"), compose_content(project))
end

return M
