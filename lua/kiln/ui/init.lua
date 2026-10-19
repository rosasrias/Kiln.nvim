-- lua/kiln/ui/init.lua
--
-- Fachada del wizard: orquesta vista, ventana y acciones.

local M = {}
local window = require("kiln.ui.window")
local actions = require("kiln.ui.actions")
local view = require("kiln.ui.views.new_project")

------------------------------------------------------------
-- Apertura
------------------------------------------------------------

function M.open()
	if window.is_open() then
		return
	end

	----------------------------------------------------------
	-- Estado + JDKs de la sesion
	----------------------------------------------------------

	actions.prepare_session()

	view.reset()

	----------------------------------------------------------
	-- Ventana
	----------------------------------------------------------

	window.open({
		width = view.WIDTH,
		height = view.HEIGHT,
		xpad = 2,
		layout = view.layout,
	})
end

------------------------------------------------------------
-- Cierre
------------------------------------------------------------

function M.close()
	window.close()
end

------------------------------------------------------------
-- Acciones delegadas
------------------------------------------------------------

M.submit = actions.submit
M.sync_defaults = actions.sync_defaults
M.set_tool = actions.set_tool
M.set_template = actions.set_template
M.cycle_jdk = actions.cycle_jdk

return M
