-- lua/kiln/scaffold/ui.lua
-- Popup "New C# Class" estilo IntelliJ, construido con volt

local volt_ui = require("volt.ui")
local utils = require("kiln.utils")
local core = require("kiln.core.scaffold")
local kinds = require("kiln.scaffold.kinds")
local window = require("kiln.ui.window")
local input = require("kiln.ui.input")
local components = require("kiln.ui.components")

local M = {}

M.WIDTH = 64
local HEADER_H = 2
M.BODY_H = 10
local FOOTER_H = 3
M.HEIGHT = HEADER_H + M.BODY_H + FOOTER_H
local LABEL_W = 10
local XPAD = 2

local S = {}
local function apply_defaults()
	S.kind = "class"
	S.name = ""
	S.extra = ""
	S.roots = {}
	S.root_i = 1
	S.pkg = ""
	S.err = nil
end
apply_defaults()

function M.state()
	return S
end
local function reset()
	apply_defaults()
end
local function clear_err()
	S.err = nil
end
local function redraw_body()
	local b = window.current_buf()
	if b then
		require("volt").redraw(b, "body")
	end
end

local function split_csv(s)
	local out = {}
	for v in (s or ""):gmatch("[^,]+") do
		v = vim.trim(v)
		if v ~= "" then
			out[#out + 1] = v
		end
	end
	return out
end

local function edit_cell(body_row, initial, on_submit)
	local winid = window.current_win()
	if not winid then
		return
	end
	if input.is_active() then
		return
	end
	local pos = vim.api.nvim_win_get_position(winid)
	local sec_row = M.layout[2].row or HEADER_H
	local xpad = XPAD
	input.open({
		value = initial,
		row = pos[1] + 1 + sec_row + body_row - 1,
		col = pos[2] + 1 + xpad + LABEL_W,
		width = 34,
		border = "none",
		winhl = "Normal:VoltField",
		on_submit = function(text)
			on_submit(text)
			clear_err()
			redraw_body()
		end,
	})
end

local function edit_name()
	edit_cell(1, S.name, function(text)
		S.name = text
	end)
end
local function edit_extra()
	edit_cell(7, S.extra, function(text)
		S.extra = text
	end)
end

function M.set_kind(key)
	if not kinds.is_valid(key) then
		return false
	end
	S.kind = key
	S.extra = ""
	clear_err()
	redraw_body()
	return true
end

function M.cycle_root()
	if #S.roots < 2 then
		return
	end
	S.root_i = (S.root_i % #S.roots) + 1
	S.pkg = core.detect_namespace(vim.api.nvim_buf_get_name(0), S.roots[S.root_i])
	clear_err()
	redraw_body()
end

function M.set_name(v)
	S.name = v or ""
end
function M.set_extra(v)
	S.extra = v or ""
end

function M.submit()
	if input.is_active() then
		return
	end
	if #S.roots == 0 then
		S.err = "No encontré proyecto .NET: abre un proyecto"
		redraw_body()
		return
	end
	if vim.trim(S.name) == "" then
		S.err = "Escribe un nombre"
		redraw_body()
		return
	end
	local force = S.err ~= nil
	local ok, res, existed = core.create({
		kind = S.kind,
		name = S.name,
		pkg = S.pkg,
		root = S.roots[S.root_i],
		values = split_csv(S.extra),
		params = split_csv(S.extra),
		force = force,
	})
	if ok then
		vim.notify("Kiln: creado " .. res, vim.log.levels.INFO)
		window.close()
		vim.schedule(function()
			vim.cmd("edit " .. vim.fn.fnameescape(res))
		end)
		return
	end
	S.err = existed and (res .. " (Create otra vez para sobreescribir)") or res
	redraw_body()
end

local function chip(label, active, action)
	return { " " .. label .. " ", active and "ButtonSelected" or "ButtonUnselected", { click = action } }
end

local function content()
	local lines = {}
	table.insert(lines, {
		{ components.pad("Name:", LABEL_W), "FieldLabel" },
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
	local root_txt = "-"
	if S.roots[S.root_i] then
		root_txt = vim.fn.fnamemodify(S.roots[S.root_i], ":h:t")
		if root_txt == "." or root_txt == "" then
			root_txt = vim.fn.fnamemodify(S.roots[S.root_i], ":t")
		end
	end
	local pkg_row = {
		{ components.pad("Namespace:", LABEL_W), "FieldLabel" },
		{ " " .. components.pad(S.pkg ~= "" and S.pkg or "(default)", 24) .. " ", "CommentFg" },
	}
	pkg_row[#pkg_row + 1] = {
		" " .. utils.truncate(root_txt, 14) .. " ▾ ",
		"ButtonSelected",
		{
			click = function()
				if #S.roots > 1 then
					S.root_i = (S.root_i % #S.roots) + 1
					S.pkg = core.detect_namespace(vim.api.nvim_buf_get_name(0), S.roots[S.root_i])
					clear_err()
					redraw_body()
				end
			end,
		},
	}
	table.insert(lines, pkg_row)
	table.insert(lines, {})
	for _, group in ipairs(kinds.GROUPS) do
		local row = {}
		for i, key in ipairs(group.keys) do
			if i > 1 then
				row[#row + 1] = { " ", "Normal" }
			end
			local def = kinds.BY_KEY[key]
			row[#row + 1] = chip(def.label, S.kind == key, function()
				M.set_kind(key)
			end)
		end
		table.insert(lines, row)
	end
	table.insert(lines, {})
	if S.kind == "enum" then
		table.insert(lines, {
			{ components.pad("Values:", LABEL_W), "FieldLabel" },
			{
				" " .. components.pad(utils.truncate(S.extra, 34), 34) .. " ",
				"VoltField",
				{
					click = function()
						vim.schedule(edit_extra)
					end,
				},
			},
		})
	elseif S.kind == "record" then
		table.insert(lines, {
			{ components.pad("Params:", LABEL_W), "FieldLabel" },
			{
				" " .. components.pad(utils.truncate(S.extra, 34), 34) .. " ",
				"VoltField",
				{
					click = function()
						vim.schedule(edit_extra)
					end,
				},
			},
		})
	else
		table.insert(lines, {})
	end
	table.insert(lines, {})
	table.insert(lines, {})
	if S.err then
		table.insert(lines, { { "! " .. utils.truncate(S.err, 56), "KilnError" } }) -- compat
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
		{ { " New C# Class ", "ProjectTitle" } },
		volt_ui.separator("─", M.WIDTH - 4, "CommentFg"),
	}
end

local function footer_button(label, id, hl, action)
	return {
		"  " .. label .. "  ",
		vim.g.nvmark_hovered == id and "SidebarHover" or hl,
		{ click = action, hover = { id = id, redraw = { "footer" } } },
	}
end

local function footer_lines()
	return {
		volt_ui.separator("─", M.WIDTH - 4, "CommentFg"),
		{ { " <CR> Seleccionar   q/<Esc> Salir ", "CommentFg" } },
		{
			footer_button("Cancel", "sc_cancel", "ButtonCancel", function()
				window.close()
			end),
			{ "    ", "Normal" },
			footer_button("Create", "sc_create", "ButtonCreate", function()
				M.submit()
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

function M.is_open()
	return window.is_open()
end
function M.open(opts)
	if window.is_open() then
		vim.notify("Kiln: cierra la ventana abierta primero", vim.log.levels.WARN)
		return
	end
	reset()
	local cur = utils.norm_dir(vim.api.nvim_buf_get_name(0))
	local start = cur ~= "" and vim.fs.dirname(cur) or vim.fn.getcwd()
	S.roots = core.find_roots(start)
	if opts and kinds.is_valid(opts.kind) then
		S.kind = opts.kind
	end
	local root = S.roots[S.root_i]
	if root then
		S.pkg = core.detect_namespace(cur, root)
	end
	window.open({ width = M.WIDTH, height = M.HEIGHT, xpad = XPAD, layout = layout })
end

function M.close()
	window.close()
end

return M
