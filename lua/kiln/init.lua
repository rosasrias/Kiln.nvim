local M = {}

function M.setup(opts)
	require("kiln.state").setup(opts)
end
function M.open()
	require("kiln.ui").open()
end
function M.close()
	require("kiln.ui").close()
end

vim.api.nvim_create_user_command("KilnProject", function()
	M.open()
end, { desc = "Kiln: abrir el asistente de proyectos" })

vim.api.nvim_create_user_command("KilnClose", function()
	M.close()
end, { desc = "Kiln: cerrar el asistente" })

vim.api.nvim_create_user_command("KilnInfo", function()
	local detector = require("kiln.core.detector")
	local project = detector.detect()
	if not project then
		vim.notify("Kiln: no se encontró un proyecto .NET", vim.log.levels.WARN)
		return
	end
	vim.notify(
		table.concat({
			"Kiln: " .. (project.name or "?"),
			"Build: " .. (project.build_tool or "dotnet"),
			"Main: " .. (project.main_class or "sin main"),
			"Framework: " .. (project.framework or "?"),
			"Namespace: " .. (project.namespace or "?"),
		}, "\n"),
		vim.log.levels.INFO
	)
end, { desc = "Kiln: información del proyecto actual" })

local SCAFFOLD_KINDS = require("kiln.scaffold.kinds")

vim.api.nvim_create_user_command("KilnNew", function(cmd_opts)
	require("kiln.scaffold.ui").open({ kind = cmd_opts.args ~= "" and cmd_opts.args or nil })
end, {
	desc = "Kiln: nueva clase/interface/enum/...",
	nargs = "?",
	complete = function()
		return vim.tbl_keys(SCAFFOLD_KINDS.BY_KEY)
	end,
})

vim.api.nvim_create_user_command("KilnNewNamespace", function()
	local scaffold_ui = require("kiln.scaffold.ui")
	if scaffold_ui.is_open() then
		vim.notify("Kiln: cierra la ventana abierta primero", vim.log.levels.WARN)
		return
	end
	local core_sc = require("kiln.core.scaffold")
	vim.ui.input({ prompt = "Namespace a crear (ej: MyApp.Core): " }, function(pkg)
		if not pkg or pkg == "" then
			return
		end
		local cur = vim.api.nvim_buf_get_name(0)
		local start = cur ~= "" and vim.fs.dirname(cur) or vim.fn.getcwd()
		local roots = core_sc.find_roots(start)
		if #roots == 0 then
			vim.notify("Kiln: no encontre proyecto .NET", vim.log.levels.ERROR)
			return
		end
		local root = roots[1]
		if #roots > 1 then
			vim.ui.select(roots, { prompt = "Raiz destino:" }, function(choice)
				if choice then
					core_sc.create_package({ pkg = pkg, root = choice })
					vim.notify("Kiln: namespace creado en " .. choice, vim.log.levels.INFO)
				end
			end)
			return
		end
		core_sc.create_package({ pkg = pkg, root = root })
		vim.notify("Kiln: namespace creado en " .. root, vim.log.levels.INFO)
	end)
end, { desc = "Kiln: crear namespace" })

vim.api.nvim_create_user_command("KilnDelete", function(cmd_opts)
	require("kiln.scaffold.ui_delete").open({ name = cmd_opts.args ~= "" and cmd_opts.args or nil })
end, {
	desc = "Kiln: eliminar clase",
	nargs = "?",
	complete = function(arglead)
		local sc = require("kiln.core.scaffold")
		local cur = vim.api.nvim_buf_get_name(0)
		local start = cur ~= "" and vim.fs.dirname(cur) or vim.fn.getcwd()
		local seen = {}
		local out = {}
		for _, root in ipairs(sc.find_roots(start)) do
			for _, p in ipairs(vim.fn.globpath(root, "**/*.cs", false, true)) do
				local base = vim.fn.fnamemodify(p, ":t:r")
				if not seen[base] then
					seen[base] = true
					if arglead == "" or base:lower():find(arglead:lower(), 1, true) then
						out[#out + 1] = base
					end
				end
			end
		end
		table.sort(out)
		return out
	end,
})

-- Alias de compatibilidad con javaforge.nvim: alli el comando equivalente es NewPackage.
vim.api.nvim_create_user_command("KilnNewPackage", function()
	vim.cmd("KilnNewNamespace")
end, { desc = "Kiln: alias de KilnNewNamespace" })

return M
