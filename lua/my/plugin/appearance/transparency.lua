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

local statusline_groups = {
  'StatusLine',
  'StatusLineNC',
  'StatusLineGitBranch',
  'StatusLineGitAdded',
  'StatusLineGitChanged',
  'StatusLineGitRemoved',
  'StatusLineDiagnosticHint',
  'StatusLineDiagnosticInfo',
  'StatusLineDiagnosticWarn',
  'StatusLineDiagnosticError',
}

---@type table<string, vim.api.keyset.highlight>
local originals = {}
---@type table<string, vim.api.keyset.get_hl_info>
local resolved = {}

---Save original attributes and links before modifying a highlight.
---@param name string
---@return nil
local function remember(name)
  if vim.fn.hlexists(name) == 1 and not originals[name] then
    originals[name] = vim.api.nvim_get_hl(0, { name = name })
    resolved[name] = vim.api.nvim_get_hl(0, { name = name, link = false })
  end
end

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
  -- Capture linked segment colors before changing their target groups.
  for _, name in ipairs(statusline_groups) do
    remember(name)
  end
  for _, name in ipairs(groups) do
    if vim.fn.hlexists(name) == 1 then
      remember(name)
      local hl = vim.deepcopy(resolved[name])
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end

  local normal_bg = M.original('Normal').bg
  local statusline_bg = resolved.StatusLine and resolved.StatusLine.bg
  if not normal_bg or not statusline_bg then
    return
  end
  local colors = require('my.utils.hl')
  for _, name in ipairs(statusline_groups) do
    local original = resolved[name]
    if original and original.bg then
      local hl = vim.deepcopy(original)
      local bg = name == 'StatusLineNC' and original.bg or statusline_bg
      hl.bg = colors.cblend(bg, normal_bg, 0.1).dec
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
