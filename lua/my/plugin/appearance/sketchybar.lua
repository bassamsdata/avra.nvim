---@class my.appearance.sketchybar
local M = {}
local fs = require('my.utils.fs')
local managed = require('my.plugin.appearance.managed')
local contrast = require('my.utils.contrast')

local config_dir = vim.fs.joinpath(
  vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config'),
  'sketchybar'
)
local theme_path = vim.fs.joinpath(config_dir, 'appearance.json')
local warned ---@type string?
local running = false
local pending = false

---@class my.appearance.sketchybar.colors
---@field bg string
---@field surface string
---@field text string
---@field muted string
---@field dim string
---@field line string
---@field warn string
---@field error string
---@field accent string
---@field fill string

local keys = {
  'accent',
  'bg',
  'dim',
  'error',
  'fill',
  'line',
  'muted',
  'surface',
  'text',
  'warn',
}

---@param message string
---@return nil
local function warn(message)
  if warned ~= message then
    warned = message
    vim.notify('SketchyBar theme: ' .. message, vim.log.levels.WARN)
  end
end

---@param colors my.appearance.sketchybar.colors
---@return string
local function checksum(colors)
  local lines = {} ---@type string[]
  for _, key in ipairs(keys) do
    lines[#lines + 1] = key .. '=' .. colors[key]
  end
  return vim.fn.sha256(table.concat(lines, '\n'))
end

---Derive bar surfaces from the same palette exported to terminal tools.
---@param palette my.appearance.ghostty.palette
---@return my.appearance.sketchybar.colors
function M.compose(palette)
  local bg, fg = palette.background, palette.foreground
  local accent = palette.accent or palette.colors[5]
  return {
    bg = bg,
    surface = contrast.blend(bg, fg, 0.04),
    text = fg,
    muted = contrast.blend(bg, fg, 0.65),
    dim = contrast.blend(bg, fg, 0.5),
    line = contrast.blend(bg, fg, 0.18),
    warn = palette.colors[4],
    error = palette.colors[2],
    accent = accent,
    fill = contrast.blend(bg, accent, 0.3),
  }
end

---Require the local palette-aware island runtime before writing anything.
---@return boolean
function M.available()
  return vim.fn.has('macunix') == 1
    and vim.fn.executable('sketchybar') == 1
    and vim.uv.fs_stat(vim.fs.joinpath(config_dir, 'plugins', 'palette.py'))
      ~= nil
end

---Validate ownership and checksum before replacing or removing our theme.
---@return boolean
local function owned()
  local stat = vim.uv.fs_lstat(theme_path)
  if not stat then
    return true
  end
  if
    stat.type ~= 'file'
    or stat.uid ~= vim.uv.getuid()
    or stat.size > 4096
  then
    warn('theme must be a small regular file owned by you: ' .. theme_path)
    return false
  end
  local ok, data = pcall(vim.json.decode, fs.read_file(theme_path) or '')
  if
    ok
    and type(data) == 'table'
    and vim.tbl_count(data) == 3
    and type(data.colors) == 'table'
    and vim.tbl_count(data.colors) == #keys
  then
    for _, key in ipairs(keys) do
      if
        type(data.colors[key]) ~= 'string'
        or not data.colors[key]:match('^#%x%x%x%x%x%x$')
        or data.colors[key] ~= data.colors[key]:lower()
      then
        ok = false
        break
      end
    end
    if
      ok
      and data.managed_by == 'avra.nvim'
      and data.checksum == checksum(data.colors)
    then
      return true
    end
  end
  warn('theme was edited outside Neovim; leaving it intact: ' .. theme_path)
  return false
end

---Serialize reloads and retry the newest palette after an in-flight reload.
---@return nil
local function reload()
  if running then
    pending = true
    return
  end
  running = true
  local ok, err = pcall(
    vim.system,
    { 'sketchybar', '--reload' },
    { text = true, timeout = 5000 },
    vim.schedule_wrap(function(result)
      running = false
      if result.code ~= 0 then
        warn('reload failed: ' .. vim.trim(result.stderr or ''))
      end
      if pending then
        pending = false
        reload()
      end
    end)
  )
  if not ok then
    running = false
    warn(tostring(err))
  end
end

---Persist palette data separately from user layout and feature settings.
---@param palette my.appearance.ghostty.palette
---@param force_reload? boolean
---@return boolean
function M.sync(palette, force_reload)
  if not M.available() or not owned() then
    return false
  end
  local colors = M.compose(palette)
  local current = fs.read_file(theme_path)
  local hash = checksum(colors)
  if current then
    local ok, data = pcall(vim.json.decode, current)
    if ok and data.checksum == hash then
      if force_reload then
        reload()
      end
      return true
    end
  end
  local content = vim.json.encode({
    managed_by = 'avra.nvim',
    colors = colors,
    checksum = hash,
  }) .. '\n'
  if not managed.write(theme_path, content) then
    warn('could not write ' .. theme_path)
    return false
  end
  warned = nil
  reload()
  return true
end

---Remove only our verified palette and restore SketchyBar's configured theme.
---@return boolean
function M.reset()
  if not M.available() or not owned() then
    return false
  end
  if vim.uv.fs_lstat(theme_path) then
    if not vim.uv.fs_unlink(theme_path) then
      warn('could not remove ' .. theme_path)
      return false
    end
    reload()
  end
  return true
end

return M
