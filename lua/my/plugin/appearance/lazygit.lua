---@class my.appearance.lazygit
local M = {}
local managed = require('my.plugin.appearance.managed')

local config_path = vim.fs.joinpath(
  vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config'),
  'lazygit',
  'config.yml'
)
local warned ---@type string?

---@param message string
---@return nil
local function warn(message)
  if warned ~= message then
    warned = message
    vim.notify('Lazygit theme: ' .. message, vim.log.levels.WARN)
  end
end

---@return boolean
function M.available()
  if
    vim.fn.executable('lazygit') ~= 1
    or vim.env.LG_CONFIG_FILE ~= nil
    or not vim.uv.fs_stat(config_path)
  then
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
---@return string
function M.compose(palette)
  local colors = palette.colors
  local values = {
    activeBorderColor = { colors[5], 'bold' },
    searchingActiveBorderColor = { colors[7], 'bold' },
    inactiveBorderColor = { colors[9] },
    optionsTextColor = { colors[5] },
    selectedLineBgColor = { palette.selection_background },
    cherryPickedCommitBgColor = { colors[7] },
    cherryPickedCommitFgColor = { palette.background },
    markedBaseCommitBgColor = { colors[4] },
    markedBaseCommitFgColor = { palette.background },
    unstagedChangesColor = { colors[2] },
    defaultFgColor = { palette.foreground },
  }
  local lines = { 'gui:', '  theme:' }
  local keys = vim.tbl_keys(values)
  table.sort(keys)
  for _, key in ipairs(keys) do
    local quoted = {} ---@type string[]
    for _, value in ipairs(values[key]) do
      quoted[#quoted + 1] = "'" .. value .. "'"
    end
    lines[#lines + 1] = '    '
      .. key
      .. ': ['
      .. table.concat(quoted, ', ')
      .. ']'
  end
  return table.concat(lines, '\n') .. '\n'
end

---@param palette my.appearance.ghostty.palette
---@return boolean
function M.sync(palette)
  if not M.available() then
    return false
  end
  local ok, err = managed.apply(config_path, 'Lazygit', M.compose(palette), {
    '^gui%s*:',
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
  local ok, err = managed.reset(config_path, 'Lazygit')
  if not ok then
    warn(err)
  else
    warned = nil
  end
end

return M
