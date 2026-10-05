---@class my.appearance.opencode
local M = {}
local fs = require('my.utils.fs')
local managed = require('my.plugin.appearance.managed')
local config = require('my.plugin.appearance.opencode_config')
local transparency = require('my.plugin.appearance.transparency')
local contrast = require('my.utils.contrast')

local config_dir = vim.fs.joinpath(
  vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, '.config'),
  'opencode'
)
local theme_name = 'avra-nvim'
local theme_path = vim.fs.joinpath(config_dir, 'themes', theme_name .. '.json')
local state_path =
  vim.fs.joinpath(vim.fn.stdpath('state'), 'opencode-sync.json')
local warned ---@type string?

---@class my.appearance.opencode.state
---@field config_path string
---@field original_theme string?
---@field theme_hash string?
---@field pending_hash string?

---@param message string
---@return nil
local function warn(message)
  if warned ~= message then
    warned = message
    vim.notify('OpenCode theme: ' .. message, vim.log.levels.WARN)
  end
end

---@return string
local function config_path()
  local jsonc = vim.fs.joinpath(config_dir, 'tui.jsonc')
  return vim.uv.fs_stat(jsonc) and jsonc
    or vim.fs.joinpath(config_dir, 'tui.json')
end

---@param path string
---@param content string
---@return boolean
local function write(path, content)
  return pcall(vim.fn.mkdir, vim.fs.dirname(path), 'p')
    and managed.write(path, content)
end

---@return my.appearance.opencode.state?, boolean
local function read_state()
  local content = fs.read_file(state_path)
  if not content then
    return nil, true
  end
  local ok, state = pcall(vim.json.decode, content)
  if
    ok
    and type(state) == 'table'
    and state.config_path == config_path()
    and (state.original_theme == nil or type(state.original_theme) == 'string')
    and (state.theme_hash == nil or type(state.theme_hash) == 'string')
    and (state.pending_hash == nil or type(state.pending_hash) == 'string')
  then
    return state, true
  end
  warn('invalid recovery state: ' .. state_path)
  return nil, false
end

---@return boolean
function M.available()
  if
    vim.fn.executable('opencode') ~= 1
    or vim.env.OPENCODE_TUI_CONFIG
    or vim.env.OPENCODE_CONFIG_DIR
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

---Export semantic highlights so any Avra colorscheme matches in OpenCode.
---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return string
function M.compose(palette, transparent)
  ---@param name string
  ---@param attr 'fg'|'bg'
  ---@param fallback string
  ---@return string
  local function color(name, attr, fallback)
    local value = transparency.original(name)[attr]
    return value and string.format('#%06x', value) or fallback
  end
  local fg, bg = palette.foreground, palette.background
  local panel = color('NormalFloat', 'bg', bg)
  local added = color('DiffAdded', 'fg', palette.colors[3])
  local removed = color('DiffRemoved', 'fg', palette.colors[2])
  local muted = color('Comment', 'fg', palette.colors[9])
  local theme = {
    primary = color('Function', 'fg', palette.colors[5]),
    secondary = color('Constant', 'fg', palette.colors[6]),
    accent = color('CursorLineNr', 'fg', palette.colors[4]),
    error = color('DiagnosticError', 'fg', palette.colors[2]),
    warning = color('DiagnosticWarn', 'fg', palette.colors[4]),
    success = color('DiagnosticOk', 'fg', added),
    info = color('DiagnosticInfo', 'fg', palette.colors[7]),
    text = fg,
    textMuted = muted,
    background = transparent and 'none' or bg,
    -- Dialogs use backgroundPanel, not backgroundMenu. Keep both opaque so
    -- underlying text cannot bleed through when the main canvas is clear.
    backgroundPanel = panel,
    backgroundElement = color('CursorLine', 'bg', panel),
    backgroundMenu = panel,
    border = color('FloatBorder', 'fg', muted),
    borderActive = color('CursorLineNr', 'fg', palette.colors[4]),
    borderSubtle = color('WinSeparator', 'fg', muted),
    diffAdded = added,
    diffRemoved = removed,
    diffContext = muted,
    diffHunkHeader = muted,
    diffHighlightAdded = added,
    diffHighlightRemoved = removed,
    diffAddedBg = color('DiffAdd', 'bg', panel),
    diffRemovedBg = color('DiffDelete', 'bg', panel),
    diffContextBg = panel,
    diffLineNumber = color('LineNr', 'fg', muted),
    diffAddedLineNumberBg = color('DiffAdd', 'bg', panel),
    diffRemovedLineNumberBg = color('DiffDelete', 'bg', panel),
    markdownText = fg,
    markdownHeading = color('Title', 'fg', palette.colors[4]),
    markdownLink = color('Underlined', 'fg', palette.colors[5]),
    markdownLinkText = color('Tag', 'fg', palette.colors[7]),
    markdownCode = color('String', 'fg', added),
    markdownBlockQuote = color('Special', 'fg', muted),
    markdownEmph = color('Special', 'fg', fg),
    markdownStrong = color('Function', 'fg', fg),
    markdownHorizontalRule = muted,
    markdownListItem = color('Type', 'fg', palette.colors[5]),
    markdownListEnumeration = color('Tag', 'fg', palette.colors[7]),
    markdownImage = color('Type', 'fg', palette.colors[5]),
    markdownImageText = color('Tag', 'fg', palette.colors[7]),
    markdownCodeBlock = fg,
    syntaxComment = muted,
    syntaxKeyword = color('Keyword', 'fg', palette.colors[6]),
    syntaxFunction = color('Function', 'fg', palette.colors[4]),
    syntaxVariable = color('Identifier', 'fg', fg),
    syntaxString = color('String', 'fg', added),
    syntaxNumber = color('Number', 'fg', palette.colors[6]),
    syntaxType = color('Type', 'fg', palette.colors[5]),
    syntaxOperator = color('Operator', 'fg', palette.colors[4]),
    syntaxPunctuation = color('Delimiter', 'fg', fg),
  }
  -- OpenCode paints focused menu rows with primary, and paste badges with
  -- warning. Neovim's Visual foreground belongs to a different background.
  theme.selectedListItemText = contrast.foreground(
    { theme.primary },
    { bg, fg, '#000000', '#ffffff' }
  )
  -- One selected-text token is shared by both surfaces. Some other Avra
  -- palettes put primary and warning at opposite ends of the lightness
  -- range; adjust only the exported warning surface when necessary.
  theme.warning =
    contrast.background(theme.selectedListItemText, theme.warning)
  -- Stable ordering avoids needless writes when the palette is unchanged.
  local lines = {
    '{',
    '  "$schema": "https://opencode.ai/theme.json",',
    '  "theme": {',
  }
  local keys = vim.tbl_keys(theme)
  table.sort(keys)
  for i, key in ipairs(keys) do
    lines[#lines + 1] = '    '
      .. vim.json.encode(key)
      .. ': '
      .. vim.json.encode(theme[key])
      .. (i < #keys and ',' or '')
  end
  lines[#lines + 1] = '  }'
  lines[#lines + 1] = '}'
  return table.concat(lines, '\n') .. '\n'
end

---Persist the theme and selection; preserve unrelated JSON/JSONC settings.
---@param palette my.appearance.ghostty.palette
---@param transparent boolean
---@return boolean
function M.sync(palette, transparent)
  if not M.available() then
    return false
  end
  local path = config_path()
  local content = fs.read_file(path) or '{}\n'
  local updated, current, err = config.theme(content, true, theme_name)
  if not updated then
    warn(err)
    return false
  end
  local state, valid = read_state()
  if not valid then
    return false
  end
  if current == theme_name and not state then
    warn('avra-nvim is selected but recovery state is missing.')
    return false
  end
  if state and current ~= theme_name and current ~= state.original_theme then
    warn('theme selection changed outside Neovim; leaving it intact.')
    return false
  end
  local existing = fs.read_file(theme_path)
  if
    existing
    and (
      not state
      or (
        vim.fn.sha256(existing) ~= state.theme_hash
        and vim.fn.sha256(existing) ~= state.pending_hash
      )
    )
  then
    warn('generated theme was edited; leaving it intact: ' .. theme_path)
    return false
  end
  state = state or { config_path = path, original_theme = current }
  local theme = M.compose(palette, transparent)
  -- Record both hashes so an interrupted atomic write can be recovered.
  state.pending_hash = vim.fn.sha256(theme)
  if not write(state_path, vim.json.encode(state)) then
    warn('could not save the original theme selection.')
    return false
  end
  if not write(theme_path, theme) then
    warn('could not write ' .. theme_path)
    return false
  end
  state.theme_hash = state.pending_hash
  state.pending_hash = nil
  if not write(state_path, vim.json.encode(state)) then
    warn('could not save the generated theme checksum.')
    return false
  end
  if (fs.read_file(path) or '{}\n') ~= content or not write(path, updated) then
    warn('TUI configuration changed or could not be written: ' .. path)
    return false
  end
  warned = nil
  return true
end

---Restore the previous selection when sync is disabled.
---@return nil
function M.reset()
  local state, valid = read_state()
  if not state or not valid then
    return
  end
  local content = fs.read_file(state.config_path)
  if not content then
    warn('could not read ' .. state.config_path)
    return
  end
  local updated, current, err =
    config.theme(content, true, state.original_theme)
  if not updated then
    warn(err)
    return
  end
  if current ~= theme_name and current ~= state.original_theme then
    warn('theme selection changed outside Neovim; leaving it intact.')
    return
  end
  if current == theme_name and not write(state.config_path, updated) then
    warn('could not restore the original theme selection.')
    return
  end
  local theme = fs.read_file(theme_path)
  if
    theme
    and (
      vim.fn.sha256(theme) == state.theme_hash
      or vim.fn.sha256(theme) == state.pending_hash
    )
  then
    vim.uv.fs_unlink(theme_path)
  end
  vim.uv.fs_unlink(state_path)
  warned = nil
end

return M
