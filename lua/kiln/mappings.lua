-- lua/kiln/mappings.lua

local M = {}

function M.setup(buf)
  local opts = {
    buffer = buf,
    silent = true,
    desc = "Kiln: cerrar el asistente",
  }

  vim.keymap.set(
    "n",
    "q",
    function()
      require("kiln.ui").close()
    end,
    opts
  )

  vim.keymap.set(
    "n",
    "<Esc>",
    function()
      require("kiln.ui").close()
    end,
    opts
  )
end

return M
