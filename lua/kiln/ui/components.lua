local M = {}

local utils = require("kiln.utils")

local function width(text)
  return vim.fn.strwidth(text)
end

function M.pad(text, size)
  local n =
      math.max(
        0,
        size - width(text)
      )

  return text .. string.rep(" ", n)
end

function M.field(label, value)
  return {
    {
      M.pad(label, 14),
      "FieldLabel",
    },
    {
      " " .. M.pad(utils.truncate(value or "", 30), 30) .. " ",
      "VoltField",
    },
  }
end

function M.button(label, highlight, callback)
  return {
    {
      " " .. label .. " ",
      highlight,
      {
        click = callback,
      },
    },
  }
end

function M.checkbox(active, label, callback)
  local icon =
      active and "" or ""

  return {
    {
      icon .. "  " .. label,
      "Normal",
      {
        click = callback,
      },
    },
  }
end

return M
