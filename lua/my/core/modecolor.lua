---@class my.core.modecolor
local M = {}
local contrast = require('my.utils.contrast')

---Configure native cursor colors and a terminal-independent mode indicator.
---@return nil
function M.setup()
  local group = vim.api.nvim_create_augroup('my.modecolor', {})
  local normal = {} ---@type vim.api.keyset.get_hl_info
  local insert = {} ---@type vim.api.keyset.get_hl_info
  local active ---@type boolean?

  ---@param name string
  ---@return vim.api.keyset.get_hl_info
  local function highlight(name)
    return vim.api.nvim_get_hl(0, {
      name = name,
      link = false,
      create = false,
    })
  end

  ---@param mode string
  ---@return nil
  local function apply(mode)
    local inserting = mode:sub(1, 1) == 'i'
    if active == inserting then
      return
    end
    active = inserting
    vim.api.nvim_set_hl(0, 'CursorLineNr', inserting and insert or normal)
  end

  ---@return nil
  local function refresh()
    normal = vim.api.nvim_get_hl(0, {
      name = 'CursorLineNr',
      create = false,
    })
    local base = highlight('Normal')
    -- Prefer a purple editing accent, distinct from green/teal backgrounds.
    local accent = highlight('Purple')
    if not accent.fg then
      accent = highlight('Statement')
    end
    if not accent.fg then
      accent = highlight('InsertMode')
    end
    local cursor = highlight('Cursor')
    insert = highlight('CursorLineNr')
    local backdrop = insert.bg
      or base.bg
      or (vim.o.background == 'light' and 0xffffff or 0x101010)
    -- Contrast is symmetric: adjust the accent as the second color, leaving
    -- the real backdrop untouched. Preserve readable theme colors verbatim.
    local color_hex = contrast.background(
      string.format('#%06x', backdrop),
      string.format('#%06x', accent.fg or 0xb2a0ee)
    )
    local color = tonumber(color_hex:sub(2), 16)
    -- Dedicated groups leave the colorscheme's Cursor/TermCursor untouched.
    vim.api.nvim_set_hl(0, 'MyModeCursorNormal', {
      fg = cursor.fg or base.bg or 0x101010,
      bg = cursor.bg or base.fg or 0xeeeeee,
    })
    vim.api.nvim_set_hl(0, 'MyModeCursorInsert', {
      fg = base.bg or 0x101010,
      bg = color,
    })
    insert.fg = color
    insert.ctermfg = accent.ctermfg or 2
    insert.reverse = nil
    -- Stable group for inspection and the accessibility report.
    vim.api.nvim_set_hl(0, 'MyModeInsertLineNr', insert)
    active = nil
    apply(vim.api.nvim_get_mode().mode)
  end

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    pattern = { '*:i*', 'i*:*' },
    desc = 'Change line-number color only when entering/leaving insert mode',
    callback = function()
      apply(vim.v.event.new_mode)
    end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = refresh,
  })
  refresh()
end

return M
