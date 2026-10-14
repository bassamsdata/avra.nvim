---@class my.appearance.ayu
local M = {}
local contrast = require('my.utils.contrast')

---Apply Ayu's warm UI accent while retaining its syntax and ANSI colors.
---@param preferred string
---@return nil
function M.apply(preferred)
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  local bg = string.format('#%06x', normal.bg)
  local fg = string.format('#%06x', normal.fg)
  local panel = contrast.blend(bg, fg, 0.08)
  local accent = contrast.background(panel, preferred:lower())
  local selected = contrast.blend(bg, accent, 0.18)
  local rgb = tonumber(accent:sub(2), 16)
  vim.api.nvim_set_hl(0, 'AvraAccent', { fg = rgb })
  for _, name in ipairs({ 'Cursor', 'CursorLineNr' }) do
    local attrs = vim.api.nvim_get_hl(0, { name = name, link = false })
    attrs[name == 'Cursor' and 'bg' or 'fg'] = rgb
    vim.api.nvim_set_hl(0, name, attrs)
  end
  for _, name in ipairs({ 'Visual', 'PmenuSel' }) do
    local attrs = vim.api.nvim_get_hl(0, { name = name, link = false })
    attrs.bg = tonumber(selected:sub(2), 16)
    attrs.fg = normal.fg
    vim.api.nvim_set_hl(0, name, attrs)
  end
end

return M
