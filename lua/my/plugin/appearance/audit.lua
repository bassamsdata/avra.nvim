---@class my.appearance.audit
local M = {}

---@class my.appearance.audit.snapshot
---@field name string
---@field requested_background string
---@field background string
---@field highlights table<string, vim.api.keyset.get_hl_info>
---@field opencode table<string, string>
---@field transparent_opencode table<string, string>
---@field palette my.appearance.ghostty.palette

---Load a theme and capture resolved highlights in an isolated Neovim.
---@param name string
---@param background 'dark'|'light'
---@return my.appearance.audit.snapshot
function M.snapshot(name, background)
  vim.o.termguicolors = true
  vim.o.background = background
  local groups = {} ---@type table<string, boolean>
  local set_hl = vim.api.nvim_set_hl
  vim.api.nvim_set_hl = function(namespace, group, attrs)
    if namespace == 0 then
      groups[group] = true
    end
    set_hl(namespace, group, attrs)
  end
  local ok, err = pcall(vim.cmd.colorscheme, name)
  vim.api.nvim_set_hl = set_hl
  if not ok then
    error(err)
  end
  require('my.core.modecolor').setup()
  groups.MyModeInsertLineNr = true
  -- Include common surfaces even when a theme inherits Neovim defaults.
  for _, group in ipairs({
    'Normal',
    'NormalFloat',
    'Pmenu',
    'PmenuSel',
    'Visual',
    'StatusLine',
    'Search',
    'IncSearch',
    'CurSearch',
    'CursorLine',
    'LineNr',
    'CursorLineNr',
    'Comment',
  }) do
    groups[group] = true
  end
  local highlights = {} ---@type table<string, vim.api.keyset.get_hl_info>
  for group in pairs(groups) do
    highlights[group] = vim.api.nvim_get_hl(0, {
      name = group,
      link = false,
      create = false,
    })
  end
  local palette =
    require('my.plugin.appearance.ghostty').palette(highlights.Normal)
  local opencode = require('my.plugin.appearance.opencode')
  local opaque = vim.json.decode(opencode.compose(palette, false)).theme
  local transparency = require('my.plugin.appearance.transparency')
  transparency.apply()
  local transparent = vim.json.decode(opencode.compose(palette, true)).theme
  transparency.restore()
  return {
    name = vim.g.colors_name,
    requested_background = background,
    background = vim.o.background,
    highlights = highlights,
    palette = palette,
    opencode = opaque,
    transparent_opencode = transparent,
  }
end

return M
