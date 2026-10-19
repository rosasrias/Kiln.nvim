-- lua/kiln/ui/highlights.lua

local api = vim.api

local M = {}

local hexadecimal_to_hex = function(hex)
	return "#" .. ("%06x"):format((hex == nil and 0 or hex))
end

local lighten = function(hex, percent)
	local ok, out = pcall(function()
		local color = require("volt.color")
		return color.change_hex_lightness(hex, percent)
	end)

	if ok then
		return out
	end

	return hex
end

local get_fg = function(name)
	local hl = api.nvim_get_hl(0, { name = name })
	return hexadecimal_to_hex(hl.fg)
end

M.setup = function()
	local base46 = vim.g.base46_cache ~= nil

	local colors = {}

	if base46 then
		local ok, cached = pcall(dofile, vim.g.base46_cache .. "colors")

		if ok and type(cached) == "table" then
			colors = {
				normal_bg = cached.normal_bg or cached.black,
				darker_bg = cached.darker_black,
				lighter_bg = cached.one_bg,
				lighter_bg2 = cached.one_bg2,
				accent = cached.blue,
				success = cached.green,
				danger = cached.red,
				muted = cached.light_grey,
				text = cached.white,
				-- base46 extendidos para categorías (rosasrias/base46 fork)
				blue = cached.blue or cached.nord_blue,
				purple = cached.purple or cached.dark_purple,
				yellow = cached.yellow or cached.sun,
				green = cached.green or cached.vibrant_green,
				vibrant_green = cached.vibrant_green or cached.green,
				cyan = cached.cyan or cached.teal,
				pink = cached.pink or cached.baby_pink,
				orange = cached.orange,
				teal = cached.teal,
			}
		end
	end

	if colors.normal_bg == nil then
		local normal_bg = hexadecimal_to_hex(api.nvim_get_hl(0, { name = "Normal" }).bg)
		local is_dark = vim.o.bg == "dark"

		colors = {
			normal_bg = normal_bg,
			darker_bg = lighten(normal_bg, is_dark and -4 or -6),
			lighter_bg = lighten(normal_bg, is_dark and 5 or 7),
			lighter_bg2 = lighten(normal_bg, is_dark and 10 or 12),
			accent = get_fg("Function"),
			success = get_fg("added"),
			danger = get_fg("removed"),
			muted = get_fg("Comment"),
			text = hexadecimal_to_hex(api.nvim_get_hl(0, { name = "Normal" }).fg),
		}
	end

	local highlights = {
		ProjectTitle = { fg = colors.accent, bold = true },
		SidebarTitle = { fg = colors.muted, bold = true },
		SidebarActive = { fg = colors.success, bold = true },
		SidebarInactive = { fg = colors.muted },
		SidebarHover = { bg = colors.lighter_bg2, fg = colors.accent },

		FieldLabel = { fg = colors.muted },
		VoltField = { bg = colors.lighter_bg2, fg = colors.text },

		ButtonSelected = { bg = colors.lighter_bg2, fg = colors.accent, bold = true },
		ButtonUnselected = { bg = colors.lighter_bg, fg = colors.muted },
		ButtonCreate = { bg = colors.success, fg = colors.darker_bg, bold = true },
		ButtonCancel = { bg = colors.danger, fg = colors.darker_bg },

		KilnError = { fg = colors.danger, bold = true },
		JavaForgeError = { fg = colors.danger, bold = true },

		-- Categorías con colores resaltantes (base46)
		CategoryGeneral = { fg = colors.blue or colors.accent, bold = true },
		CategoryAspNet = { fg = colors.purple or "#c882e7", bold = true }, -- violeta
		CategoryServicios = { fg = colors.yellow or "#e7c787", bold = true }, -- amarillo
		CategoryDesktop = { fg = colors.vibrant_green or colors.green, bold = true }, -- verde
		CategoryTesting = { fg = colors.pink or "#ff75a0", bold = true }, -- rosa
		CategorySolucion = { fg = colors.orange or colors.cyan or "#fca2aa", bold = true }, -- naranja/cyan
	}

	for name, val in pairs(highlights) do
		api.nvim_set_hl(0, name, val)
	end
end

return M
