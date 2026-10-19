-- lua/kiln/ui/window.lua
--
-- Shell generico del wizard: buffer + ventana flotante +
-- ciclo de vida con limpieza completa de volt.

local volt = require("volt")

-- Hotfix volt #1014: Invalid window id tras "Create Project" con click de mouse.
-- handle_click() hace vim.schedule(nvim_win_set_cursor) y submit() cierra la ventana
-- inmediatamente → el schedule intenta operar sobre ventana ya inválida.
-- Parche global idempotente para evitar el throw aunque volt no esté actualizado.
do
	if not vim.g._kiln_volt_patched then
		local orig_set_cursor = vim.api.nvim_win_set_cursor
		vim.api.nvim_win_set_cursor = function(win, pos)
			if not win or not vim.api.nvim_win_is_valid(win) then
				return
			end
			local ok, err = pcall(orig_set_cursor, win, pos)
			if not ok then
				-- silenciar solo Invalid window, propagar otros errores reales
				if not tostring(err):match("Invalid window") then
					error(err)
				end
			end
		end
		vim.g._kiln_volt_patched = true
	end
end

local M = {}

local buf
local win
local winclosed_auid

------------------------------------------------------------
-- Estado
------------------------------------------------------------

function M.is_open()
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.current_buf()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
end

function M.current_win()
	if win and vim.api.nvim_win_is_valid(win) then
		return win
	end
end

function M.redraw(name)
	local b = M.current_buf()

	if b then
		require("volt").redraw(b, name)
	end
end

------------------------------------------------------------
-- Limpieza
------------------------------------------------------------

function M.close()
	if winclosed_auid then
		pcall(vim.api.nvim_del_autocmd, winclosed_auid)

		winclosed_auid = nil
	end

	require("kiln.ui.input").close()

	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end

	win = nil

	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, {
			force = true,
		})
	end

	----------------------------------------------------------
	-- Volt cleanup
	----------------------------------------------------------

	local vstate = require("volt.state")

	if buf then
		vstate[buf] = nil

		local event_bufs = require("volt.events").bufs

		for i, bufid in ipairs(event_bufs) do
			if bufid == buf then
				table.remove(event_bufs, i)
				break
			end
		end
	end
end

------------------------------------------------------------
-- Apertura
------------------------------------------------------------

--- opts: { width, height, xpad, layout }
function M.open(opts)
	if M.is_open() then
		return
	end

	----------------------------------------------------------
	-- Highlights
	----------------------------------------------------------

	require("kiln.ui.highlights").setup()

	----------------------------------------------------------
	-- Buffer
	----------------------------------------------------------

	buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].bufhidden = "wipe"

	----------------------------------------------------------
	-- Volt data
	----------------------------------------------------------

	local ns = vim.api.nvim_create_namespace("kiln.ui")

	volt.gen_data({
		{
			buf = buf,

			xpad = opts.xpad or 2,

			layout = opts.layout,

			ns = ns,
		},
	})

	----------------------------------------------------------
	-- Ventana centrada
	----------------------------------------------------------

	local row = math.max(0, math.floor((vim.o.lines - opts.height) / 2))

	local col = math.max(0, math.floor((vim.o.columns - opts.width) / 2))

	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = opts.width,
		height = opts.height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = false
	vim.wo[win].scrolloff = 0
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].wrap = false
	-- Bloquear scroll de rueda (evita gran espacio bajo footer en floating window)
	for _, mode in ipairs({ "n", "i", "v" }) do
		vim.keymap.set(mode, "<ScrollWheelDown>", "<Nop>", { buffer = buf, silent = true, nowait = true })
		vim.keymap.set(mode, "<ScrollWheelUp>", "<Nop>", { buffer = buf, silent = true, nowait = true })
		vim.keymap.set(mode, "<S-ScrollWheelDown>", "<Nop>", { buffer = buf, silent = true, nowait = true })
		vim.keymap.set(mode, "<S-ScrollWheelUp>", "<Nop>", { buffer = buf, silent = true, nowait = true })
		vim.keymap.set(mode, "<ScrollWheelLeft>", "<Nop>", { buffer = buf, silent = true, nowait = true })
		vim.keymap.set(mode, "<ScrollWheelRight>", "<Nop>", { buffer = buf, silent = true, nowait = true })
	end
	-- Fallback: si el usuario tiene mousescroll personalizado, neutralizarlo localmente
	pcall(vim.api.nvim_set_option_value, "mousescroll", "ver:0,hor:0", { win = win })

	----------------------------------------------------------
	-- Volt
	----------------------------------------------------------

	volt.run(buf, {
		h = opts.height,
		w = opts.width,
	})

	----------------------------------------------------------
	-- Volt events (mouse + <CR>/<Tab>)
	----------------------------------------------------------

	require("volt.events").add(buf)

	----------------------------------------------------------
	-- Mappings
	----------------------------------------------------------

	require("kiln.mappings").setup(buf)

	----------------------------------------------------------
	-- Cierre externo de la ventana
	----------------------------------------------------------

	winclosed_auid = vim.api.nvim_create_autocmd("WinClosed", {
		buffer = buf,

		callback = function()
			vim.schedule(function()
				local vstate = require("volt.state")

				if vstate[buf] then
					M.close()
				end
			end)
		end,
	})
end

return M
