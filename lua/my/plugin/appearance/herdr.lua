---@class my.appearance.herdr
local M = {}
local fs = require('my.utils.fs')

local original ---@type string?
local written ---@type string?
local config_path ---@type string?
local warned = false
local marker = '# Avra managed theme'

---@return string
local function binary()
  return vim.env.HERDR_BIN_PATH or 'herdr'
end

---Only synchronize a local, attached Herdr terminal session.
---@return boolean
function M.available()
  if vim.env.HERDR_ENV ~= '1' or vim.fn.executable(binary()) ~= 1 then
    return false
  end
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.stdout_tty then
      return true
    end
  end
  return false
end

---@param message string
---@return nil
local function warn(message)
  if not warned then
    warned = true
    vim.notify('Herdr theme: ' .. message, vim.log.levels.WARN)
  end
end

---Replace only the custom theme table; retain all other configuration.
---@param content string
---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return string
function M.compose(content, palette, transparent)
  local lines = {} ---@type string[]
  local skip = false
  for line in (content .. '\n'):gmatch('(.-)\n') do
    if line:match('^%s*%[') then
      local section = line:match('^%s*%[([^%]]+)%]')
      skip = section == 'theme.custom'
        or section == 'theme.custom.light'
        or section == 'theme.custom.dark'
    end
    if not skip then
      lines[#lines + 1] = line
    end
  end
  local background = transparent and 'reset' or palette.background
  local colors = palette.colors
  local tokens = {
    accent = colors[5],
    panel_bg = background,
    sidebar_bg = background,
    active_row_bg = palette.selection_background,
    selection_bg = palette.selection_background,
    surface0 = background,
    surface1 = background,
    surface_dim = background,
    overlay0 = colors[9],
    overlay1 = colors[9],
    text = palette.foreground,
    subtext0 = colors[9],
    mauve = colors[6],
    green = colors[3],
    yellow = colors[4],
    red = colors[2],
    blue = colors[5],
    teal = colors[7],
    peach = colors[4],
  }
  lines[#lines + 1] = marker
  lines[#lines + 1] = '[theme.custom]'
  local keys = vim.tbl_keys(tokens)
  table.sort(keys)
  for _, key in ipairs(keys) do
    lines[#lines + 1] = key .. ' = "' .. tokens[key] .. '"'
  end
  return table.concat(lines, '\n') .. '\n'
end

---@return nil
local function reload()
  local ok, result = pcall(function()
    return vim
      .system({ binary(), 'server', 'reload-config' }, { text = true })
      :wait(1500)
  end)
  if not ok or result.code ~= 0 then
    warn('could not reload the running server configuration.')
  end
end

---Apply colors to Herdr's chrome as well as Neovim's terminal pane.
---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return boolean
function M.sync(palette, transparent)
  if not M.available() then
    return false
  end
  config_path = config_path
    or vim.env.HERDR_CONFIG_PATH
    or vim.fs.joinpath(
      vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config'),
      'herdr',
      'config.toml'
    )
  config_path = vim.uv.fs_realpath(config_path) or config_path
  local current = fs.read_file(config_path)
  if not current then
    warn('configuration could not be read: ' .. config_path)
    return false
  end
  if written and current ~= written then
    warn('configuration was edited; leaving your changes intact.')
    return false
  end
  if not original then
    local backup_path = config_path .. '.avra-backup'
    local backup = fs.read_file(backup_path)
    local previous = fs.read_file(config_path .. '.avra-theme')
    if backup and (current == backup or current == previous) then
      original = backup
    elseif backup then
      warn('a previous backup exists: ' .. backup_path)
      return false
    elseif fs.write_file(backup_path, current) then
      original = current
      local stat = vim.uv.fs_stat(config_path)
      if stat then
        vim.uv.fs_chmod(backup_path, stat.mode)
      end
    else
      warn('could not back up your configuration.')
      return false
    end
  end
  local content = M.compose(original, palette, transparent)
  if content == written then
    return true
  end
  local temporary = config_path .. '.avra-' .. vim.fn.getpid() .. '.tmp'
  if not fs.write_file(temporary, content) then
    warn('could not write the temporary theme configuration.')
    return false
  end
  -- Validate TOML with Herdr itself before touching the live config.
  local ok, result = pcall(function()
    return vim
      .system({ binary(), 'config', 'check' }, {
        env = { HERDR_CONFIG_PATH = temporary },
        text = true,
      })
      :wait(1500)
  end)
  if not ok or result.code ~= 0 then
    vim.uv.fs_unlink(temporary)
    local detail = ok and vim.trim(result.stderr .. result.stdout)
      or tostring(result)
    warn('configuration validation failed: ' .. detail:gsub('\n', ' '))
    return false
  end
  if fs.read_file(config_path) ~= current then
    vim.uv.fs_unlink(temporary)
    warn('configuration was edited; leaving your changes intact.')
    return false
  end
  local stat = vim.uv.fs_stat(config_path)
  if not fs.write_file(config_path .. '.avra-theme', content) then
    vim.uv.fs_unlink(temporary)
    warn('could not record the theme for crash recovery.')
    return false
  end
  if stat then
    vim.uv.fs_chmod(temporary, stat.mode)
    vim.uv.fs_chmod(config_path .. '.avra-backup', stat.mode)
    vim.uv.fs_chmod(config_path .. '.avra-theme', stat.mode)
  end
  if not vim.uv.fs_rename(temporary, config_path) then
    vim.uv.fs_unlink(temporary)
    warn('could not install the validated theme configuration.')
    return false
  end
  written = content
  reload()
  return true
end

---Restore the baseline, or keep the applied theme on normal exit.
---@param persist? boolean
---@return nil
function M.reset(persist)
  if persist and written and config_path then
    if fs.read_file(config_path) == written then
      vim.uv.fs_unlink(config_path .. '.avra-backup')
      vim.uv.fs_unlink(config_path .. '.avra-theme')
      original, written = nil, nil
      return
    end
  end
  if original and not written and config_path then
    if fs.read_file(config_path) == original then
      vim.uv.fs_unlink(config_path .. '.avra-backup')
      vim.uv.fs_unlink(config_path .. '.avra-theme')
    end
  end
  if original and written and config_path then
    if fs.read_file(config_path) == written then
      local temporary = config_path .. '.avra-' .. vim.fn.getpid() .. '.tmp'
      if fs.write_file(temporary, original) then
        local stat = vim.uv.fs_stat(config_path)
        if stat then
          vim.uv.fs_chmod(temporary, stat.mode)
        end
        if vim.uv.fs_rename(temporary, config_path) then
          reload()
          vim.uv.fs_unlink(config_path .. '.avra-backup')
          vim.uv.fs_unlink(config_path .. '.avra-theme')
        else
          vim.uv.fs_unlink(temporary)
          warn('could not restore the original theme configuration.')
        end
      else
        vim.uv.fs_unlink(temporary)
        warn('could not restore the original theme configuration.')
      end
    else
      warn('configuration was edited; leaving your changes intact.')
    end
  end
  original, written = nil, nil
end

return M
