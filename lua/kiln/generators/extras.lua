-- lua/kiln/generators/extras.lua

local utils = require("kiln.utils")

local M = {}

local GITIGNORE_DOTNET = {
  "bin/",
  "obj/",
  "*.user",
  "*.suo",
  ".vs/",
  "*.dbmdl",
  "*.jfm",
}

local GITIGNORE_COMMON = {
  ".idea/",
  "*.log",
  ".vscode/",
}

local EDITORCONFIG = {
  "root = true",
  "",
  "[*]",
  "charset = utf-8",
  "end_of_line = lf",
  "insert_final_newline = true",
  "trim_trailing_whitespace = true",
  "indent_style = space",
  "indent_size = 4",
  "",
  "[*.{cs,csproj,sln}]",
  "indent_size = 4",
  "",
  "[*.{json,yml,yaml}]",
  "indent_size = 2",
  "",
}

local GITATTRIBUTES = {
  "* text=auto",
  "",
  "*.cs text diff=csharp",
  "*.csproj text",
  "*.sln text",
  "*.json text",
  "*.md text",
  "*.sh text eol=lf",
  "",
  "*.dll binary",
  "*.exe binary",
  "*.png binary",
  "",
}

local function write_lines(root, name, lines)
  utils.write_file(vim.fs.joinpath(root, name), table.concat(lines, "\n") .. "\n")
end

function M.apply(project, root)
  local features = project.features or {}
  if features.git then
    local ignore = {}
    vim.list_extend(ignore, GITIGNORE_DOTNET)
    vim.list_extend(ignore, GITIGNORE_COMMON)
    write_lines(root, ".gitignore", ignore)
  end
  if features.meta_files then
    write_lines(root, ".editorconfig", EDITORCONFIG)
    write_lines(root, ".gitattributes", GITATTRIBUTES)
  end
end

return M
