-- lua/kiln/ui/input.lua
--
-- Float de edicion inline para un campo del wizard.
-- Posicionado sobre la celda clicada.

local M = {}

local ibuf
local iwin
local active = false

------------------------------------------------------------
-- Estado
------------------------------------------------------------

function M.is_active()
  return active
      and iwin ~= nil
      and vim.api.nvim_win_is_valid(iwin)
end

--- Id de la ventana del float (tests / posicion).
function M.current_win()
  return iwin
end

------------------------------------------------------------
-- Cierre
------------------------------------------------------------

function M.close()
  local parent = M.parent_win

  if iwin
      and vim.api.nvim_win_is_valid(iwin)
  then
    vim.api.nvim_win_close(
      iwin,
      true
    )
  end

  iwin = nil

  if ibuf
      and vim.api.nvim_buf_is_valid(ibuf)
  then
    vim.api.nvim_buf_delete(
      ibuf,
      {
        force = true,
      }
    )
  end

  ibuf = nil

  active = false
  M.cfg = nil

  if parent
      and vim.api.nvim_win_is_valid(parent)
  then
    vim.api.nvim_set_current_win(parent)
  end

  M.parent_win = nil
end

------------------------------------------------------------
-- Apertura
------------------------------------------------------------

--- cfg: { value, row, col, width, on_submit(text) }
function M.open(cfg)
  if M.is_active() then
    return false
  end

  M.close()

  M.cfg = cfg

  M.parent_win =
      require("kiln.ui.window")
          .current_win()

  ibuf =
      vim.api.nvim_create_buf(
        false,
        true
      )

  vim.bo[ibuf].bufhidden = "wipe"
  vim.bo[ibuf].buftype = "prompt"

  local value = cfg.value or ""

  vim.bo[ibuf].modifiable = true

  vim.api.nvim_buf_set_lines(
    ibuf,
    0,
    -1,
    false,
    { value }
  )

  iwin =
      vim.api.nvim_open_win(
        ibuf,
        true,
        {
          relative = "editor",

          row = cfg.row,

          col = cfg.col,

          width = cfg.width or 40,

          height = 1,

          style = "minimal",

          border = cfg.border or "single",
        }
      )

  if cfg.winhl then
    vim.wo[iwin].winhl = cfg.winhl
  end

  vim.wo[iwin].number = false
  vim.wo[iwin].relativenumber = false

  vim.fn.prompt_setprompt(ibuf, "")

  ----------------------------------------------------------
  -- Enter: aplicar valor
  ----------------------------------------------------------

  vim.fn.prompt_setcallback(
    ibuf,
    function(text)
      M.submit(text)
    end
  )

  ----------------------------------------------------------
  -- Esc: cancelar
  ----------------------------------------------------------

  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(
      mode,
      "<Esc>",
      function()
        M.close()
      end,
      {
        buffer = ibuf,
        nowait = true,
        silent = true,
      }
    )
  end

  vim.cmd("startinsert")

  active = true

  return true
end

------------------------------------------------------------
-- Confirmacion (Enter en el prompt; tambien invocable
-- desde tests para reproducir el flujo real)
------------------------------------------------------------

function M.submit(text)
  if not M.is_active() then
    return false
  end

  text = vim.trim(text or "")

  local cfg = M.cfg

  M.close()

  if cfg and cfg.on_submit then
    pcall(cfg.on_submit, text)
  end

  return true
end

return M
