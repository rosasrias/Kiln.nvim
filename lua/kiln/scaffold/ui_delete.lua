-- lua/kiln/scaffold/ui_delete.lua
--
-- Popup "Delete CSharp Class" estilo IntelliJ:
-- buscar por nombre, elegir coincidencia y borrar
-- (opcionalmente su test asociado).

local utils = require("kiln.utils")
local core = require("kiln.core.scaffold")
local window = require("kiln.ui.window")
local input = require("kiln.ui.input")
local components = require("kiln.ui.components")
local volt_ui = require("volt.ui")

local M = {}

M.WIDTH = 64

local HEADER_H = 2
local LABEL_W = 10
local XPAD = 2
local MAX_RESULTS = 5

M.BODY_H = 12

local FOOTER_H = 3

M.HEIGHT = HEADER_H + M.BODY_H + FOOTER_H

------------------------------------------------------------
-- Estado
------------------------------------------------------------

local S = {}

local function apply_defaults()
	S.name = ""
	S.start = ""
	S.roots = {}
	S.results = {}
	S.sel_i = 1
	S.tests = true
	S.armed = false
	S.err = nil
end

apply_defaults()

function M.state()
	return S
end

local function clear_flags()
	S.err = nil
	S.armed = false
end

local function redraw_body()
	local b = window.current_buf()

	if b then
		require("volt").redraw(b, "body")
	end
end

------------------------------------------------------------
-- Input inline sobre la celda Name
------------------------------------------------------------

local function edit_name()
	local winid = window.current_win()

	if not winid or input.is_active() then
		return
	end

	local pos = vim.api.nvim_win_get_position(winid)

	local sec_row = M.layout[2].row or HEADER_H

	input.open({
		value = S.name,

		row = pos[1] + 1 + sec_row,

		col = pos[2] + 1 + XPAD + LABEL_W,

		width = 34,

		border = "none",

		winhl = "Normal:VoltField",

		on_submit = function(text)
			S.name = text or ""

			M.refresh()
		end,
	})
end

------------------------------------------------------------
-- Acciones publicas (UI y tests)
------------------------------------------------------------

function M.set_name(v)
	S.name = v or ""
end

function M.toggle_tests()
	S.tests = not S.tests
	clear_flags()
	redraw_body()
end

--- Re-ejecuta la busqueda con el nombre actual.
function M.refresh()
	clear_flags()

	S.results = core.find_by_name(S.name, {
		start_dir = S.start,
		roots = S.roots,
	})

	if S.sel_i > #S.results then
		S.sel_i = #S.results > 0 and 1 or 0
	end

	redraw_body()

	return #S.results
end

function M.select(i)
	if i >= 1 and i <= #S.results then
		S.sel_i = i
		clear_flags()
		redraw_body()
	end
end

--- Primer press arma la confirmacion; segundo borra.
function M.delete_selected()
	if input.is_active() then
		return
	end

	if #S.results == 0 then
		S.err = "No encontre ninguna clase con ese nombre"
		redraw_body()
		return
	end

	local sel = S.results[S.sel_i]

	if not sel then
		return
	end

	if not S.armed then
		S.armed = true

		S.err = "Pulsa Delete otra vez para confirmar"

		redraw_body()
		return
	end

	----------------------------------------------------------
	-- Confirmado: juntar target + tests asociados
	----------------------------------------------------------

	local paths = { sel.path }

	if S.tests then
		for _, t in ipairs(core.related_tests(sel.path)) do
			paths[#paths + 1] = t
		end
	end

	local res = core.delete_files(paths)

	vim.notify(string.format("kiln: %d archivo(s) eliminado(s)", #res.deleted), vim.log.levels.INFO)

	window.close()

	vim.schedule(function()
		vim.cmd("checktime")
	end)
end

------------------------------------------------------------
-- Vista
------------------------------------------------------------

local function content()
	local lines = {}

	----------------------------------------------------------
	-- Fila 1: Name
	----------------------------------------------------------

	table.insert(lines, {
		{
			components.pad("Name:", LABEL_W),
			"FieldLabel",
		},

		{
			" " .. components.pad(utils.truncate(S.name, 34), 34) .. " ",

			"VoltField",

			{
				click = function()
					vim.schedule(edit_name)
				end,
			},
		},
	})

	----------------------------------------------------------
	-- Fila 2: status de busqueda
	----------------------------------------------------------

	local n = #S.results

	local status_txt = n == 0 and (S.name == "" and "(escribe un nombre)" or "sin coincidencias")
		or n .. " coincidencia(s)"

	table.insert(lines, {
		{
			" " .. status_txt,
			"CommentFg",
		},
	})

	----------------------------------------------------------
	-- Fila 3: separador
	----------------------------------------------------------

	table.insert(lines, {})

	----------------------------------------------------------
	-- Filas 4-8: resultados seleccionables
	----------------------------------------------------------

	for i = 1, MAX_RESULTS do
		local r = S.results[i]

		if r then
			local txt =
				string.format("%s.%s   [%s]", r.pkg ~= "" and r.pkg or "(default)", vim.fn.fnamemodify(r.path, ":t"), vim.fn.fnamemodify(r.root, ":h:t"))

			table.insert(lines, {
				{
					" " .. components.pad(utils.truncate(txt, 52), 54),

					i == S.sel_i and "ButtonSelected" or "SidebarInactive",

					{
						click = function()
							M.select(i)
						end,
					},
				},
			})
		else
			table.insert(lines, {})
		end
	end

	----------------------------------------------------------
	-- Fila 9: separador
	----------------------------------------------------------

	table.insert(lines, {})

	----------------------------------------------------------
	-- Fila 10: checkbox tests asociados
	----------------------------------------------------------

	table.insert(
		lines,
		components.checkbox(S.tests, "Eliminar tests asociados", function()
			M.toggle_tests()
		end)
	)

	----------------------------------------------------------
	-- Fila 11: separador
	----------------------------------------------------------

	table.insert(lines, {})

	----------------------------------------------------------
	-- Fila 12: error / confirmacion
	----------------------------------------------------------

	if S.err then
		table.insert(lines, {
			{
				"! " .. utils.truncate(S.err, 56),

				S.armed and "ButtonSelected" or "KilnError",
			},
		})
	else
		table.insert(lines, {})
	end

	while #lines < M.BODY_H do
		table.insert(lines, {})
	end

	return lines
end

local function header_lines()
	return {
		{
			{
				" Delete CSharp Class ",
				"ProjectTitle",
			},
		},

		volt_ui.separator("─", M.WIDTH - 4, "CommentFg"),
	}
end

local function footer_button(label, id, hl, action)
	return {
		"  " .. label .. "  ",
		vim.g.nvmark_hovered == id and "SidebarHover" or hl,

		{
			click = action,

			hover = {
				id = id,
				redraw = { "footer" },
			},
		},
	}
end

local function footer_lines()
	return {
		volt_ui.separator("─", M.WIDTH - 4, "CommentFg"),

		{
			{
				" <CR> Seleccionar   q/<Esc> Salir ",
				"CommentFg",
			},
		},

		{
			footer_button("Cancel", "del_cancel", "ButtonCancel", function()
				----------------------------------------------------
				-- SIN vim.schedule: volt agrega un set_cursor
				-- sobre esta ventana justo despues del click.
				----------------------------------------------------

				window.close()
			end),

			{ "    ", "Normal" },

			footer_button("Delete", "del_delete", "ButtonCancel", function()
				M.delete_selected()
			end),
		},
	}
end

local layout = {
	{ name = "header", lines = header_lines },

	{ name = "body", lines = content },

	{ name = "footer", lines = footer_lines },
}

M.layout = layout

------------------------------------------------------------
-- Ciclo de vida
------------------------------------------------------------

function M.is_open()
	return window.is_open()
end

--- opts: { name = prefill + auto-search }
function M.open(opts)
	if window.is_open() then
		vim.notify("kiln: cierra la ventana abierta primero", vim.log.levels.WARN)
		return
	end

	apply_defaults()

	----------------------------------------------------------
	-- Contexto: archivo actual o cwd
	----------------------------------------------------------

	local cur = utils.norm_dir(vim.api.nvim_buf_get_name(0))

	S.start = cur ~= "" and vim.fs.dirname(cur) or vim.fn.getcwd()

	S.roots = core.find_roots(S.start)

	if opts and opts.name then
		S.name = opts.name
		S.results = core.find_by_name(S.name, {
			start_dir = S.start,
			roots = S.roots,
		})
	end

	window.open({
		width = M.WIDTH,
		height = M.HEIGHT,
		xpad = XPAD,
		layout = layout,
	})
end

function M.close()
	window.close()
end

return M
