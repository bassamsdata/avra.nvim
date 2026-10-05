---@class my.appearance.yazi
local M = {}
local managed = require('my.plugin.appearance.managed')

local config_path = vim.fs.joinpath(
  vim.env.YAZI_CONFIG_HOME
    or vim.fs.joinpath(
      vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config'),
      'yazi'
    ),
  'theme.toml'
)
local warned ---@type string?

---@param message string
---@return nil
local function warn(message)
  if warned ~= message then
    warned = message
    vim.notify('Yazi theme: ' .. message, vim.log.levels.WARN)
  end
end

---@return boolean
function M.available()
  if vim.fn.executable('yazi') ~= 1 or not vim.uv.fs_stat(config_path) then
    return false
  end
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.stdout_tty then
      return true
    end
  end
  return false
end

---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return string
function M.compose(palette, transparent)
  local colors = palette.colors
  local background = transparent and 'reset' or palette.background
  local lines = {
    '[app]',
    'overall = { fg = "'
      .. palette.foreground
      .. '", bg = "'
      .. background
      .. '" }',
    '',
    '[mgr]',
    'cwd = { fg = "' .. colors[5] .. '" }',
    'find_keyword = { fg = "' .. colors[4] .. '", bold = true }',
    'find_position = { fg = "' .. colors[6] .. '" }',
    'marker_copied = { fg = "'
      .. colors[3]
      .. '", bg = "'
      .. colors[3]
      .. '" }',
    'marker_cut = { fg = "' .. colors[2] .. '", bg = "' .. colors[2] .. '" }',
    'marker_selected = { fg = "'
      .. colors[4]
      .. '", bg = "'
      .. colors[4]
      .. '" }',
    'border_style = { fg = "' .. colors[9] .. '" }',
    '',
    '[tabs]',
    'active = { fg = "'
      .. palette.background
      .. '", bg = "'
      .. colors[5]
      .. '", bold = true }',
    'inactive = { fg = "' .. colors[9] .. '", bg = "' .. background .. '" }',
    '',
    '[mode]',
    'normal_main = { fg = "'
      .. palette.background
      .. '", bg = "'
      .. colors[5]
      .. '", bold = true }',
    'select_main = { fg = "'
      .. palette.background
      .. '", bg = "'
      .. colors[3]
      .. '", bold = true }',
    'unset_main = { fg = "'
      .. palette.background
      .. '", bg = "'
      .. colors[2]
      .. '", bold = true }',
    '',
    '[status]',
    'overall = { fg = "'
      .. palette.foreground
      .. '", bg = "'
      .. background
      .. '" }',
    'perm_read = { fg = "' .. colors[4] .. '" }',
    'perm_write = { fg = "' .. colors[2] .. '" }',
    'perm_exec = { fg = "' .. colors[3] .. '" }',
    '',
    '[notify]',
    'title_info = { fg = "' .. colors[3] .. '" }',
    'title_warn = { fg = "' .. colors[4] .. '" }',
    'title_error = { fg = "' .. colors[2] .. '" }',
  }
  return table.concat(lines, '\n') .. '\n'
end

---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return boolean
function M.sync(palette, transparent)
  if not M.available() then
    return false
  end
  local ok, err =
    managed.apply(config_path, 'Yazi', M.compose(palette, transparent), {
      '^%[app%]',
      '^%[mgr%]',
      '^%[tabs%]',
      '^%[mode%]',
      '^%[status%]',
      '^%[notify%]',
    })
  if not ok then
    warn(err)
  else
    warned = nil
  end
  return ok
end

---@return nil
function M.reset()
  local ok, err = managed.reset(config_path, 'Yazi')
  if not ok then
    warn(err)
  else
    warned = nil
  end
end

return M
