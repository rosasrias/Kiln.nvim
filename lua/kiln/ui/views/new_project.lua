-- lua/kiln/ui/views/new_project.lua
-- Wizard con catálogo completo agrupado

local ui = require("volt.ui")
local state = require("kiln.state")
local utils = require("kiln.utils")
local components = require("kiln.ui.components")
local actions = require("kiln.ui.actions")
local input = require("kiln.ui.input")
local window = require("kiln.ui.window")
local catalog = require("kiln.catalog")

local M = {}

M.WIDTH = 115
M.HEIGHT = 35

local HEADER_H = 2
M.BODY_H = 33

local SIDEBAR_W = 32
local SIDEBAR_PAD = 4

local VALUE_COL = SIDEBAR_W + SIDEBAR_PAD + 14 + 1

local fields = {
	{ key = "name", label = "Name:" },
	{ key = "location", label = "Location:" },
	{ key = "namespace", label = "Namespace:" },
}

local field_rows = {}
function M.reset()
	field_rows = {}
end

local function get_value(key)
	local project = state.get()
	if key == "namespace" then
		return project.namespace
	end
	if key == "framework" then
		return project.framework
	end
	return project[key]
end

local function set_value(key, value)
	local project = state.get()
	if key == "namespace" then
		project.namespace = value
	elseif key == "framework" then
		project.framework = value
	else
		project[key] = value
	end
	if vim.list_contains({ "name", "namespace" }, key) then
		state.mark_edited(key)
	end
end

local function clear_errors()
	state.update({ errors = {} })
end

local layout
local function edit_field(key)
	local win = window.current_win()
	if not win then
		return
	end
	local pos = vim.api.nvim_win_get_position(win)
	local body_section = layout[2]
	local line_in_win = (body_section.row or 0) + (field_rows[key] or 1) - 1
	input.open({
		value = get_value(key),
		row = pos[1] + line_in_win,
		col = pos[2] + VALUE_COL,
		width = 35,
		on_submit = function(text)
			set_value(key, text)
			actions.sync_defaults()
			clear_errors()
			window.redraw("body")
		end,
	})
end

local function sidebar_item(txt, active, action, id)
	local hovered = id ~= nil and vim.g.nvmark_hovered == id
	local hl = "SidebarInactive"
	if active then
		hl = "SidebarActive"
	end
	if hovered then
		hl = "SidebarHover"
	end
	return { { txt, hl, action and { click = action, hover = { id = id, redraw = { "body" } } } or nil } }
end

local function sidebar()
	local project = state.get()
	local lines = {
		{ { " LANGUAGE ", "SidebarTitle" } },
		sidebar_item("  ● C#", true, nil, "lang_csharp"),
		{ { "", "Normal" } },
	}
	for _, group in ipairs(catalog.grouped()) do
		-- categoría con emoji textual + highlight por categoría (base46 violeta/azul/amarillo/verde)
		local cat_label = group.category
		local cat_hl = "SidebarTitle"
		if cat_label == "General" then
			cat_label = "🖥️ General"
			cat_hl = "CategoryGeneral"
		elseif cat_label == "ASP.NET Core" then
			cat_label = "🌐 ASP.NET Core"
			cat_hl = "CategoryAspNet"
		elseif cat_label == "Servicios" then
			cat_label = "🔌 Servicios"
			cat_hl = "CategoryServicios"
		elseif cat_label == "Desktop" then
			cat_label = "🖼️ Desktop"
			cat_hl = "CategoryDesktop"
		elseif cat_label == "Testing" then
			cat_label = "🧪 Testing"
			cat_hl = "CategoryTesting"
		elseif cat_label == "Solución" then
			cat_label = "📦 Solución"
			cat_hl = "CategorySolucion"
		end
		table.insert(lines, { { " " .. cat_label .. " ", cat_hl } })
		for _, tpl in ipairs(group.items) do
			local active = project.template == tpl.key
			local txt = (active and "  ● " or "  ○ ") .. tpl.label
			-- truncar si etiqueta muy larga
			txt = utils.truncate(txt, SIDEBAR_W - 2)
			table.insert(
				lines,
				sidebar_item(txt, active, function()
					actions.set_template(tpl.key)
				end, "tpl_" .. tpl.key)
			)
		end
	end
	return lines
end

local function content()
	local project = state.get()
	local lines = {}
	local idx = 0
	idx = idx + 1
	table.insert(lines, { { "Project", "ProjectTitle" } })
	idx = idx + 1
	table.insert(lines, {})

	for _, field in ipairs(fields) do
		local value = get_value(field.key)
		idx = idx + 1
		field_rows[field.key] = idx
		local row = components.field(field.label, value)
		row[2][3] = {
			click = function()
				vim.schedule(function()
					edit_field(field.key)
				end)
			end,
		}
		if field.key == "location" then
			table.insert(row, {
				" ⋯ ",
				"ButtonSelected",
				{
					click = function()
						vim.schedule(function()
							actions.pick_location()
						end)
					end,
				},
			})
		end
		table.insert(lines, row)
		idx = idx + 1
		table.insert(lines, {})
	end

	-- Framework editable + info plantilla actual
	idx = idx + 1
	field_rows["framework"] = idx
	local tpl_info = catalog.BY_KEY[project.template]
	local fw_label = tpl_info and tpl_info.description or project.template
	local fw_row = components.field("Framework:", project.framework)
	fw_row[2][3] = {
		click = function()
			vim.schedule(function()
				edit_field("framework")
			end)
		end,
	}
	table.insert(lines, fw_row)
	-- línea info template + dotnet new
	idx = idx + 1
	table.insert(
		lines,
		{ { "  ↳ " .. fw_label .. (tpl_info and ("  · dotnet new " .. tpl_info.dotnet) or ""), "CommentFg" } }
	)

	-- SDK + TFM ciclo
	idx = idx + 1
	local sdk_txt = "no detectado"
	if project.sdk then
		sdk_txt = project.sdk.label or ("SDK " .. tostring(project.sdk.version))
	end
	local fw_txt = project.framework or "-"
	table.insert(lines, {
		{ "SDK:", "FieldLabel" },
		{
			" " .. utils.truncate(sdk_txt, 22) .. " ▾ ",
			"ButtonSelected",
			{
				click = function()
					actions.cycle_sdk()
				end,
			},
		},
		{ "   ", "Normal" },
		{ "TFM:", "FieldLabel" },
		{
			" " .. fw_txt .. " ▾ ",
			"ButtonSelected",
			{
				click = function()
					actions.cycle_framework()
				end,
			},
		},
	})

	-- Chips contextuales solo para webapi (NuGet extras)
	idx = idx + 1
	if project.template == "webapi" then
		local chips = {}
		local defs = {
			{ key = "efcore", label = "EF Core" },
			{ key = "swagger", label = "Swagger" },
			{ key = "auth", label = "Auth" },
		}
		for i, def in ipairs(defs) do
			if i > 1 then
				table.insert(chips, { " ", "Normal" })
			end
			local on = project.webapi[def.key]
			table.insert(chips, {
				" " .. def.label .. " ",
				on and "ButtonSelected" or "ButtonUnselected",
				{
					click = function()
						actions.toggle_webapi_feature(def.key)
					end,
				},
			})
		end
			table.insert(lines, chips)
		idx = idx + 1
		table.insert(lines, {})
	else
		table.insert(lines, {})
	end

	-- Features: NuGet-aware labels
	local features = {
		{ key = "git", txt = "Create Git repository" },
		{ key = "sample_code", txt = "Add sample code" },
		{ key = "tests", txt = "Add tests (NuGet)" },
		{ key = "meta_files", txt = "Add .editorconfig & .gitattributes" },
		{ key = "multi_project", txt = "Multi-project (Core/App) + .sln" },
	}
	if catalog.is_web(project.template) then
		table.insert(features, { key = "docker", txt = "Add Dockerfile & docker-compose" })
	end
	for _, f in ipairs(features) do
		idx = idx + 1
		table.insert(lines, {
			ui.checkbox({
				active = project.features[f.key],
				txt = f.txt,
				hlon = "String",
				hloff = "CommentFg",
				actions = {
					click = function()
						local p = state.get()
						p.features[f.key] = not p.features[f.key]
						clear_errors()
						window.redraw("body")
					end,
				},
			}),
		})
	end
	for _ = #features, 5 do
		idx = idx + 1
		table.insert(lines, {})
	end

	local errors = state.get().errors or {}
	for i = 1, 2 do
		idx = idx + 1
		local err = errors[i]
		if err then
			table.insert(lines, { { "! " .. utils.truncate(err, 64), "KilnError" } })
		else
			table.insert(lines, {})
		end
	end
	-- Relleno antes del footer para que los botones queden pegados al final del body (no bajo el sidebar)
	while #lines < M.BODY_H - 3 do
		table.insert(lines, {})
	end
	-- Footer embebido bajo el cuerpo (derecha, no full-width)
	table.insert(lines, ui.separator("─", 74, "CommentFg"))
	table.insert(lines, { { " <CR> Seleccionar  <Tab> Siguiente  q/<Esc> Salir ", "CommentFg" } })
	table.insert(lines, {
		{ "  Cancel  ", vim.g.nvmark_hovered == "btn_cancel" and "SidebarHover" or "ButtonCancel", { click = function() vim.schedule(function() window.close() end) end, hover = { id = "btn_cancel", redraw = { "body" } } } },
		{ "    ", "Normal" },
		{ "  Create Project  ", vim.g.nvmark_hovered == "btn_create" and "SidebarHover" or "ButtonCreate", { click = function() vim.schedule(function() actions.submit() end) end, hover = { id = "btn_create", redraw = { "body" } } } },
	})
	return lines
end

local function header_lines()
	return {
		{ { " Kiln — " .. #catalog.TEMPLATES .. " plantillas NuGet ", "ProjectTitle" } },
		ui.separator("─", M.WIDTH - 4, "CommentFg"),
	}
end

layout = {
	{ name = "header", lines = header_lines },
	{
		name = "body",
		lines = function()
			return ui.grid_col({
				{ lines = sidebar(), w = SIDEBAR_W, pad = SIDEBAR_PAD },
				{ lines = content(), w = 78 },
			})
		end,
	},
}

M.layout = layout
M.edit_field = edit_field

return M
