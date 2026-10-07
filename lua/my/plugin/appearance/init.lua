---@class my.appearance
local M = {}
local transparency = require('my.plugin.appearance.transparency')
local json = require('my.utils.json')

---@return my.appearance.ghostty
local function ghostty()
  return require('my.plugin.appearance.ghostty')
end

---@return my.appearance.ghostty_config
local function ghostty_config()
  return require('my.plugin.appearance.ghostty_config')
end

---@return my.appearance.herdr
local function herdr()
  return require('my.plugin.appearance.herdr')
end

---@return my.appearance.btop
local function btop()
  return require('my.plugin.appearance.btop')
end

---@return my.appearance.lazygit
local function lazygit()
  return require('my.plugin.appearance.lazygit')
end

---@return my.appearance.yazi
local function yazi()
  return require('my.plugin.appearance.yazi')
end

---@return my.appearance.opencode
local function opencode()
  return require('my.plugin.appearance.opencode')
end

---@class my.appearance.settings
---@field transparent boolean
---@field ghostty_sync boolean
---@field herdr_sync boolean
---@field btop_sync boolean
---@field lazygit_sync boolean
---@field yazi_sync boolean
---@field opencode_sync boolean
---@field ghostty_persist boolean
---@field herdr_persist boolean

---@alias my.appearance.setting 'transparent'|'ghostty_sync'|'herdr_sync'|'btop_sync'|'lazygit_sync'|'yazi_sync'|'opencode_sync'|'ghostty_persist'|'herdr_persist'
---@alias my.appearance.switch 'on'|'off'|'toggle'

local state_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'appearance.json')
---@type my.appearance.settings
local settings = {
  transparent = false,
  ghostty_sync = true,
  herdr_sync = true,
  btop_sync = true,
  lazygit_sync = true,
  yazi_sync = true,
  opencode_sync = true,
  ghostty_persist = false,
  herdr_persist = false,
}
local initialized = false
local pending = false
local ready = false
local startup_pending = false

---@return table<my.appearance.setting, boolean>
local function read_settings()
  local stored = json.read(state_path)
  ---@type table<my.appearance.setting, boolean>
  local result = {}
  if type(stored) == 'table' then
    for key in pairs(settings) do
      if type(stored[key]) == 'boolean' then
        result[key] = stored[key]
      end
    end
  end
  return result
end

---@param keys my.appearance.setting[]
---@return nil
local function save(keys)
  local stored = read_settings()
  for _, key in ipairs(keys) do
    -- Neovide keeps its highlight transparency choice session-local.
    if key ~= 'transparent' or not vim.g.neovide then
      stored[key] = settings[key]
    end
  end
  local ok = pcall(vim.fn.mkdir, vim.fs.dirname(state_path), 'p')
  local temporary = state_path .. '.' .. vim.fn.getpid() .. '.tmp'
  if
    not ok
    or not json.write(temporary, stored)
    or not vim.uv.fs_rename(temporary, state_path)
  then
    vim.uv.fs_unlink(temporary)
    vim.notify('Could not save Avra appearance settings.', vim.log.levels.WARN)
  end
end

---Synchronize enabled tools after an explicit appearance change.
---@param force_reload? boolean
---@return nil
local function refresh(force_reload)
  local palette = ghostty().palette(transparency.original('Normal'))
  if settings.transparent then
    transparency.apply()
  end
  if settings.ghostty_sync then
    local host_available = ghostty_config().available()
    ghostty_config().sync(palette, force_reload)
    -- Herdr consumes OSC in its virtual pane. Direct Ghostty must use only
    -- config colors: OSC resets in 1.3.1 leave overrides that block reloads.
    if vim.env.HERDR_ENV == '1' or not host_available then
      ghostty().sync(palette, settings.transparent)
    end
  end
  if settings.herdr_sync then
    herdr().sync(palette, settings.transparent)
  end
  if settings.btop_sync then
    btop().sync(palette, settings.transparent)
  end
  if settings.lazygit_sync then
    lazygit().sync(palette)
  end
  if settings.yazi_sync then
    yazi().sync(palette, settings.transparent)
  end
  if settings.opencode_sync then
    opencode().sync(palette, settings.transparent)
  end
end

---@return nil
local function schedule_refresh()
  if not ready then
    return
  end
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    refresh()
  end)
end

---Finish startup after UIEnter and its colorscheme restoration have run.
---@return nil
local function finish_startup()
  if ready or startup_pending then
    return
  end
  startup_pending = true
  vim.schedule(function()
    startup_pending = false
    if settings.transparent then
      transparency.apply()
    end
    ready = true
  end)
end

---@param message string
---@return nil
local function warn(message)
  vim.notify('Appearance: ' .. message, vim.log.levels.WARN)
end

---@param value string?
---@return boolean
local function valid_switch(value)
  return value == nil or value == 'on' or value == 'off' or value == 'toggle'
end

---@param keys my.appearance.setting[]
---@param value my.appearance.switch?
---@return nil
local function set(keys, value)
  local enabled = value == 'on' or (value ~= 'off' and not settings[keys[1]])
  for _, key in ipairs(keys) do
    settings[key] = enabled
  end
  save(keys)
end

---Show saved preferences and currently available sync backends.
---@return nil
local function status()
  local lines = {} ---@type string[]
  for _, target in ipairs({ 'ghostty', 'herdr' }) do
    lines[#lines + 1] = string.format(
      '%s: sync %s, persist %s',
      target,
      settings[target .. '_sync'] and 'on' or 'off',
      settings[target .. '_persist'] and 'on' or 'off'
    )
  end
  lines[#lines + 1] = 'transparency: '
    .. (settings.transparent and 'on' or 'off')
  lines[#lines + 1] = 'btop: sync '
    .. (settings.btop_sync and 'on' or 'off')
    .. ' (persistent)'
  lines[#lines + 1] = 'BTOP sync available: ' .. tostring(btop().available())
  for _, target in ipairs({ 'lazygit', 'yazi', 'opencode' }) do
    lines[#lines + 1] = target
      .. ': sync '
      .. (settings[target .. '_sync'] and 'on' or 'off')
      .. ' (persistent)'
  end
  lines[#lines + 1] = 'Lazygit sync available: '
    .. tostring(lazygit().available())
  lines[#lines + 1] = 'Yazi sync available: ' .. tostring(yazi().available())
  lines[#lines + 1] = 'OpenCode sync available: '
    .. tostring(opencode().available())
  lines[#lines + 1] = 'Ghostty global sync available: '
    .. tostring(ghostty_config().available())
  local host = ghostty_config().status()
  lines[#lines + 1] = 'Ghostty config: ' .. host.config_path
  lines[#lines + 1] = 'Ghostty owner: '
    .. (host.owner_pid and ('Neovim PID ' .. host.owner_pid) or 'none')
    .. ' (this Neovim: '
    .. vim.fn.getpid()
    .. ')'
  lines[#lines + 1] = 'Ghostty theme installed by this session: '
    .. tostring(host.applied)
  lines[#lines + 1] = 'Ghostty reload pending: '
    .. tostring(host.reload_pending)
  if host.error then
    lines[#lines + 1] = 'Ghostty warning: ' .. host.error
  end
  lines[#lines + 1] = 'Herdr sync available: ' .. tostring(herdr().available())
  vim.notify(table.concat(lines, '\n'))
end

---@param path string?
---@return nil
local function export(path)
  path = path and vim.fn.expand(path)
    or vim.fs.joinpath(vim.fn.stdpath('state'), 'ghostty-theme')
  local ok = pcall(vim.fn.mkdir, vim.fs.dirname(path), 'p')
  if
    ok
    and ghostty().export(
      path,
      ghostty().palette(transparency.original('Normal'))
    )
  then
    vim.notify('Ghostty theme exported to ' .. path)
  else
    warn('could not export Ghostty theme to ' .. path)
  end
end

---Dispatch the single public appearance command.
---@param args vim.api.keyset.create_user_command.command_args
---@return nil
local function command(args)
  local words = args.fargs
  local action = words[1] or 'status'
  if action == 'status' and #words <= 1 then
    status()
  elseif action == 'refresh' and #words == 1 then
    refresh(true)
    status()
  elseif action == 'export' and #words <= 2 then
    export(words[2])
  elseif action == 'persist' then
    local target = words[2] or 'all'
    local value = words[3]
    if
      (target ~= 'all' and target ~= 'ghostty' and target ~= 'herdr')
      or not valid_switch(value)
      or #words > 3
    then
      warn('usage: :Appearance persist [all|ghostty|herdr] [on|off|toggle]')
      return
    end
    local keys = target == 'all' and { 'ghostty_persist', 'herdr_persist' }
      or { target .. '_persist' }
    set(keys, value)
    status()
  elseif
    action == 'transparency'
    or action == 'ghostty'
    or action == 'herdr'
    or action == 'btop'
    or action == 'lazygit'
    or action == 'yazi'
    or action == 'opencode'
  then
    if not valid_switch(words[2]) or #words > 2 then
      warn('usage: :Appearance ' .. action .. ' [on|off|toggle]')
      return
    end
    local key = action == 'transparency' and 'transparent' or action .. '_sync'
    set({ key }, words[2])
    if action == 'transparency' and not settings.transparent then
      transparency.restore()
    elseif action == 'ghostty' and not settings.ghostty_sync then
      ghostty_config().reset()
      ghostty().reset()
    elseif action == 'herdr' and not settings.herdr_sync then
      herdr().reset()
    elseif action == 'btop' and not settings.btop_sync then
      btop().reset()
    elseif action == 'lazygit' and not settings.lazygit_sync then
      lazygit().reset()
    elseif action == 'yazi' and not settings.yazi_sync then
      yazi().reset()
    elseif action == 'opencode' and not settings.opencode_sync then
      opencode().reset()
    end
    refresh()
    vim.notify(action .. ' ' .. (settings[key] and 'on' or 'off'))
  else
    warn(
      'usage: :Appearance '
        .. '[status|refresh|transparency|ghostty|herdr|btop|lazygit|yazi|opencode|persist|export]'
    )
  end
end

---@param lead string
---@param line string
---@return string[]
local function complete(lead, line)
  local words = vim.split(line, '%s+', { trimempty = true })
  local index = #words - (line:match('%s$') and 0 or 1)
  local candidates = {} ---@type string[]
  if index == 1 then
    candidates = {
      'status',
      'refresh',
      'transparency',
      'ghostty',
      'herdr',
      'btop',
      'lazygit',
      'yazi',
      'opencode',
      'persist',
      'export',
    }
  elseif words[2] == 'persist' and index == 2 then
    candidates = { 'all', 'ghostty', 'herdr' }
  elseif
    (words[2] == 'persist' and index == 3)
    or (
      (
        words[2] == 'transparency'
        or words[2] == 'ghostty'
        or words[2] == 'herdr'
        or words[2] == 'btop'
        or words[2] == 'lazygit'
        or words[2] == 'yazi'
        or words[2] == 'opencode'
      ) and index == 2
    )
  then
    candidates = { 'on', 'off', 'toggle' }
  elseif words[2] == 'export' and index == 2 then
    return vim.fn.getcompletion(lead, 'file')
  end
  return vim.tbl_filter(function(value)
    return vim.startswith(value, lead)
  end, candidates)
end

---Register appearance handlers without synchronizing external tools.
---@param source_event? string
---@return nil
function M.setup(source_event)
  if initialized then
    return
  end
  initialized = true
  for key, value in pairs(read_settings()) do
    settings[key] = value
  end
  if vim.g.neovide then
    settings.transparent = false
  end
  vim.api.nvim_create_user_command('Appearance', command, {
    nargs = '*',
    complete = complete,
    desc = 'Manage transparency, terminal themes, and persistence',
  })
  local group = vim.api.nvim_create_augroup('my.appearance', {})
  vim.api.nvim_create_autocmd('ColorSchemePre', {
    group = group,
    callback = function()
      transparency.restore()
      for i = 0, 15 do
        vim.g['terminal_color_' .. i] = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = schedule_refresh,
  })
  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = 'background',
    callback = schedule_refresh,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      local host = package.loaded['my.plugin.appearance.ghostty_config']
      if host then
        host.reset(settings.ghostty_persist)
      end
      local terminal = package.loaded['my.plugin.appearance.ghostty']
      if terminal then
        terminal.reset()
      end
      local multiplex = package.loaded['my.plugin.appearance.herdr']
      if multiplex then
        multiplex.reset(settings.herdr_persist)
      end
    end,
  })
  vim.api.nvim_create_autocmd('UIEnter', {
    group = group,
    once = true,
    callback = finish_startup,
  })
  if source_event == 'UIEnter' or vim.v.vim_did_enter == 1 then
    finish_startup()
  end
end

return M
