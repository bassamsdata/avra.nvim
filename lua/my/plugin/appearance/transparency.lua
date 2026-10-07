---@class my.appearance.transparency
local M = {}

local groups = {
  'Normal',
  'NormalNC',
  'NormalSpecial',
  'NormalFloat',
  'FloatBorder',
  'EndOfBuffer',
  'SignColumn',
  'LineNr',
  'CursorLineNr',
  'FoldColumn',
  'WinSeparator',
  'VertSplit',
  'TabLineFill',
  'WinBar',
  'WinBarNC',
}

---@type table<string, vim.api.keyset.highlight>
local originals = {}
---@type table<string, vim.api.keyset.get_hl_info>
local resolved = {}

---Read a highlight before its background was cleared.
---@param name string
---@return vim.api.keyset.get_hl_info
function M.original(name)
  return resolved[name]
    or vim.api.nvim_get_hl(0, { name = name, link = false, create = false })
end

---Clear backgrounds without losing foregrounds or text styles.
---@return nil
function M.apply()
  for _, name in ipairs(groups) do
    if vim.fn.hlexists(name) == 1 then
      if not originals[name] then
        originals[name] = vim.api.nvim_get_hl(0, { name = name })
        resolved[name] = vim.api.nvim_get_hl(0, { name = name, link = false })
      end
      local hl = vim.deepcopy(resolved[name])
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

---Restore original attributes and links, then forget the old theme.
---@return nil
function M.restore()
  for name, hl in pairs(originals) do
    vim.api.nvim_set_hl(0, name, hl)
  end
  originals = {}
  resolved = {}
end

return M
