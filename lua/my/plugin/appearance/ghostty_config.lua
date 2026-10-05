---@class my.appearance.ghostty_config
local M = {}
local fs = require('my.utils.fs')
local ghostty = require('my.plugin.appearance.ghostty')

---@class my.appearance.ghostty_config.snapshot
---@field pid integer
---@field config_path string
---@field theme_path string
---@field original_config? string
---@field original_theme? string
---@field written_config string
---@field written_theme string

---@class my.appearance.ghostty_config.status
---@field config_path string
---@field owner_pid? integer
---@field applied boolean
---@field reload_pending boolean
---@field error? string

local state_dir = vim.fn.stdpath('state')
local journal_path = vim.fs.joinpath(state_dir, 'ghostty-sync.json')
local theme_path = vim.fs.joinpath(state_dir, 'ghostty-sync-theme')
local marker = '# Avra managed theme'
local snapshot ---@type my.appearance.ghostty_config.snapshot?
local warned ---@type string?
local reload_pending = false

---@param message string
---@return nil
local function warn(message)
  if warned ~= message then
    warned = message
    vim.notify('Ghostty theme: ' .. message, vim.log.levels.WARN)
  end
end

---Resolve the last native config so its include overrides XDG themes.
---@return string
local function config_path()
  if vim.env.GHOSTTY_CONFIG_PATH then
    return vim.env.GHOSTTY_CONFIG_PATH
  end
  local directory = vim.fs.joinpath(
    vim.env.HOME,
    'Library/Application Support/com.mitchellh.ghostty'
  )
  local modern = vim.fs.joinpath(directory, 'config.ghostty')
  local legacy = vim.fs.joinpath(directory, 'config')
  return vim.uv.fs_stat(modern) and modern
    or vim.uv.fs_stat(legacy) and legacy
    or modern
end

---Global reloads are supported only on a local macOS Ghostty host.
---@return boolean
function M.available()
  return vim.fn.has('mac') == 1
    and not vim.env.SSH_CONNECTION
    and not vim.env.SSH_TTY
    and (vim.env.TERM_PROGRAM == 'ghostty' or vim.env.GHOSTTY_RESOURCES_DIR ~= nil)
    and vim.fn.executable('ghostty') == 1
    and vim.fn.executable('osascript') == 1
    and ghostty.available()
end

---Report ownership and reload state without changing the configuration.
---@return my.appearance.ghostty_config.status
function M.status()
  local owner_pid = snapshot and snapshot.pid
  local path = snapshot and snapshot.config_path or config_path()
  local content = fs.read_file(journal_path)
  if not snapshot and content then
    local ok, record = pcall(vim.json.decode, content)
    if ok and type(record) == 'table' then
      if type(record.pid) == 'number' then
        owner_pid = record.pid
      end
      if type(record.config_path) == 'string' then
        path = record.config_path
      end
    end
  end
  return {
    config_path = path,
    owner_pid = owner_pid,
    applied = snapshot ~= nil,
    reload_pending = reload_pending,
    error = warned,
  }
end

---@param path string
---@param content string?
---@return boolean
local function write(path, content)
  if content == nil then
    return not vim.uv.fs_stat(path) or vim.uv.fs_unlink(path) ~= nil
  end
  local ok = pcall(vim.fn.mkdir, vim.fs.dirname(path), 'p')
  local temporary = path .. '.avra-' .. vim.fn.getpid() .. '.tmp'
  if not ok then
    return false
  end
  local stat = vim.uv.fs_stat(path)
  local fd = vim.uv.fs_open(temporary, 'w', stat and stat.mode or 384)
  if not fd then
    return false
  end
  local written = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  if written ~= #content then
    vim.uv.fs_unlink(temporary)
    return false
  end
  if not vim.uv.fs_rename(temporary, path) then
    vim.uv.fs_unlink(temporary)
    return false
  end
  return true
end

---@return boolean
local function reload()
  local script = [[
    if application "Ghostty" is not running then return false
    tell application "Ghostty"
      set target to focused terminal of selected tab of front window
      return perform action "reload_config" on target
    end tell
  ]]
  local ok, result = pcall(function()
    return vim
      .system({ 'osascript', '-e', script }, { text = true })
      :wait(3000)
  end)
  if not ok or result.code ~= 0 or vim.trim(result.stdout or '') ~= 'true' then
    warn(
      'reload failed; allow macOS Automation access to Ghostty, '
        .. 'then run :Appearance refresh. '
        .. (ok and vim.trim(result.stderr or '') or tostring(result))
    )
    reload_pending = true
    return false
  end
  reload_pending = false
  warned = nil
  return true
end

---@param record my.appearance.ghostty_config.snapshot
---@return boolean
local function unedited(record)
  return fs.read_file(record.config_path) == record.written_config
    and fs.read_file(record.theme_path) == record.written_theme
end

---@param record my.appearance.ghostty_config.snapshot
---@return boolean
local function restore(record)
  if not unedited(record) then
    warn(
      'configuration or generated theme was edited; '
        .. 'leaving your changes and recovery journal intact.'
    )
    return false
  end
  -- Restore the theme first: a persistent baseline may already include it.
  if
    not write(record.theme_path, record.original_theme)
    or not write(record.config_path, record.original_config)
  then
    warn('could not restore the original configuration.')
    return false
  end
  vim.uv.fs_unlink(journal_path)
  return true
end

---@return boolean
local function recover()
  local content = fs.read_file(journal_path)
  if not content then
    return true
  end
  local ok, record = pcall(vim.json.decode, content)
  if
    not ok
    or type(record) ~= 'table'
    or type(record.pid) ~= 'number'
    or type(record.config_path) ~= 'string'
    or type(record.theme_path) ~= 'string'
    or type(record.written_config) ~= 'string'
    or type(record.written_theme) ~= 'string'
    or (record.original_config ~= nil and type(record.original_config) ~= 'string')
    or (
      record.original_theme ~= nil
      and type(record.original_theme) ~= 'string'
    )
  then
    warn('invalid recovery journal: ' .. journal_path)
    return false
  end
  if record.pid ~= vim.fn.getpid() and vim.uv.kill(record.pid, 0) then
    warn('another Neovim session controls Ghostty; leaving it in charge.')
    return false
  end
  -- A crash may have happened between journal creation and either write.
  local current_config = fs.read_file(record.config_path)
  local current_theme = fs.read_file(record.theme_path)
  if
    (
      current_config ~= record.written_config
      and current_config ~= record.original_config
    )
    or (
      current_theme ~= record.written_theme
      and current_theme ~= record.original_theme
    )
  then
    warn(
      'configuration was edited after a crash; '
        .. 'leaving the recovery journal intact.'
    )
    return false
  end
  if
    not write(record.theme_path, record.original_theme)
    or not write(record.config_path, record.original_config)
  then
    warn('could not recover the original configuration.')
    return false
  end
  vim.uv.fs_unlink(journal_path)
  return true
end

---Write and reload the outer Ghostty theme, including from inside Herdr.
---@param palette my.appearance.ghostty.palette
---@param force_reload? boolean Retry even when the palette is unchanged
---@return boolean
function M.sync(palette, force_reload)
  if not M.available() then
    return false
  end
  if snapshot and not unedited(snapshot) then
    warn('configuration was edited; leaving your changes intact.')
    return false
  end
  local record = snapshot
  if not record then
    if not recover() then
      return false
    end
    local path = config_path()
    path = vim.uv.fs_realpath(path) or path
    local original = fs.read_file(path)
    local original_theme = fs.read_file(theme_path)
    -- A committed theme already has this include; keep its position.
    local include = 'config-file = ' .. theme_path
    local content = original or ''
    if not content:find(include, 1, true) then
      content = content
        .. (content:sub(-1) == '\n' and '' or '\n')
        .. marker
        .. '\n'
        .. include
        .. '\n'
    end
    record = {
      pid = vim.fn.getpid(),
      config_path = path,
      theme_path = theme_path,
      original_config = original,
      original_theme = original_theme,
      written_config = content,
      written_theme = original_theme or '',
    }
  end
  local content = ghostty.compose(palette)
  if snapshot and content == snapshot.written_theme then
    return not (reload_pending or force_reload) or reload()
  end
  local candidate =
    vim.fs.joinpath(state_dir, 'ghostty-candidate-' .. vim.fn.getpid())
  if not write(candidate, content) then
    warn('could not write the candidate theme.')
    return false
  end
  local ok, result = pcall(function()
    return vim
      .system({
        'ghostty',
        '+validate-config',
        '--config-file=' .. candidate,
      }, { text = true })
      :wait(1500)
  end)
  vim.uv.fs_unlink(candidate)
  if not ok or result.code ~= 0 then
    warn(
      'generated theme failed validation: '
        .. (
          ok and vim.trim((result.stderr or '') .. (result.stdout or ''))
          or tostring(result)
        )
    )
    return false
  end
  -- Journal both originals before writing either live file.
  if snapshot and not unedited(snapshot) then
    warn('configuration was edited during validation; leaving it intact.')
    return false
  end
  if
    not snapshot
    and (
      fs.read_file(record.config_path) ~= record.original_config
      or fs.read_file(theme_path) ~= record.original_theme
      or fs.read_file(journal_path)
    )
  then
    warn('configuration or session ownership changed during validation.')
    return false
  end
  record = vim.deepcopy(record)
  record.written_theme = content
  local encoded = vim.json.encode(record)
  local saved ---@type boolean?
  if snapshot then
    saved = write(journal_path, encoded)
  else
    -- Reserve ownership atomically if two sessions start together.
    local fd = vim.uv.fs_open(journal_path, 'wx', 384)
    if fd then
      saved = vim.uv.fs_write(fd, encoded, 0) == #encoded
      vim.uv.fs_close(fd)
      if not saved then
        vim.uv.fs_unlink(journal_path)
      end
    end
  end
  if not saved then
    warn('could not save the recovery journal.')
    return false
  end
  if
    not write(theme_path, content)
    or not write(record.config_path, record.written_config)
  then
    -- Restore any partial write; retain the journal if recovery fails.
    if
      write(record.theme_path, record.original_theme)
      and write(record.config_path, record.original_config)
    then
      vim.uv.fs_unlink(journal_path)
    end
    snapshot = nil
    warn('could not install the Ghostty theme.')
    return false
  end
  snapshot = record
  reload_pending = true
  return reload()
end

---Restore the baseline, or commit the applied colors on normal exit.
---@param persist? boolean
---@return nil
function M.reset(persist)
  if not snapshot then
    return
  end
  if persist and unedited(snapshot) then
    vim.uv.fs_unlink(journal_path)
  elseif restore(snapshot) then
    reload()
  end
  snapshot = nil
end

return M
