---@class my.core.modecolor
local M = {}
local contrast = require('my.utils.contrast')

---@param name string
---@return vim.api.keyset.get_hl_info
local function highlight(name)
  return vim.api.nvim_get_hl(0, {
    name = name,
    link = false,
    create = false,
  })
end

---@param color integer
---@return string
local function hex(color)
  return string.format('#%06x', color)
end

---Choose a visible insert cursor that differs from the normal cursor.
---@param background integer
---@param normal integer
---@return integer, integer? fill, preferred text
local function insert_color(background, normal)
  ---@param color integer?
  ---@return integer?
  local function usable(color)
    if not color or color == normal then
      return nil
    end
    local adjusted =
      tonumber(contrast.background(hex(background), hex(color), 3):sub(2), 16)
    return adjusted ~= normal and adjusted or nil
  end

  for _, name in ipairs({
    'iCursor',
    'CursorInsert',
    'InsertCursor',
    'CursorIM',
  }) do
    local attrs = highlight(name)
    local fill_color, text_color = attrs.bg, attrs.fg
    if attrs.reverse then
      fill_color, text_color = attrs.fg, attrs.bg
    end
    local fill = usable(fill_color)
    if fill then
      return fill, text_color
    end
  end
  for _, name in ipairs({
    'InsertMode',
    'String',
    'DiagnosticOk',
    'Function',
    'Statement',
    'Special',
  }) do
    local attrs = highlight(name)
    local fill = usable(name == 'InsertMode' and attrs.bg or attrs.fg)
    if fill then
      return fill
    end
  end
  -- Minimal themes may define neither a cursor nor any syntax accents.
  return usable(0x5faf5f) or usable(0xb2a0ee) or background
end

---Configure native per-mode cursors without touching line-number colors.
---@return nil
function M.setup()
  local group = vim.api.nvim_create_augroup('my.modecolor', {})

  ---@return nil
  local function refresh()
    local transparency = package.loaded['my.plugin.appearance.transparency']
    local base = transparency and transparency.original('Normal')
      or highlight('Normal')
    local bg = base.bg
      or (vim.o.background == 'light' and 0xffffff or 0x101010)
    local fg = base.fg
      or (vim.o.background == 'light' and 0x222222 or 0xeeeeee)
    local cursor = highlight('Cursor')
    local normal_bg = cursor.reverse and (cursor.fg or fg) or cursor.bg or fg
    local normal_fg = cursor.reverse and (cursor.bg or bg) or cursor.fg or bg
    local color, preferred_text = insert_color(bg, normal_bg)
    local text = contrast.foreground(
      { hex(color) },
      { hex(preferred_text or bg), hex(fg), '#000000', '#ffffff' }
    )
    -- Neovim emits cursor colors through guicursor; no per-mode subprocesses.
    vim.api.nvim_set_hl(0, 'MyModeCursorNormal', {
      fg = normal_fg,
      bg = normal_bg,
    })
    vim.api.nvim_set_hl(0, 'MyModeCursorInsert', {
      fg = tonumber(text:sub(2), 16),
      bg = color,
    })

    -- Paused: the cursor now provides the insert-mode cue.
    -- local number = highlight('CursorLineNr')
    -- vim.api.nvim_set_hl(0, 'MyModeNormalLineNr', number)
    -- number.fg = color
    -- number.reverse = nil
    -- vim.api.nvim_set_hl(0, 'MyModeInsertLineNr', number)
  end

  -- vim.api.nvim_create_autocmd('ModeChanged', {
  --   group = group,
  --   pattern = { '*:i*', 'i*:*' },
  --   desc = 'Change line-number color when entering/leaving insert mode',
  --   callback = function()
  --     local inserting = vim.v.event.new_mode:sub(1, 1) == 'i'
  --     vim.api.nvim_set_hl(0, 'CursorLineNr', {
  --       link = inserting and 'MyModeInsertLineNr' or 'MyModeNormalLineNr',
  --     })
  --   end,
  -- })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = refresh,
  })
  refresh()
end

return M
