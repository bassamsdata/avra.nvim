---@class my.plugin.secrets
local M = {}

local ns = vim.api.nvim_create_namespace('my.secrets')
---@type table<integer, boolean>
local enabled = {}
---@type table<integer, {level: integer, cursor: string}>
local windows = {}
---@type {level: integer, cursor: string}?
local inherited = nil
local initialized = false

---Restore window options when leaving a protected buffer or revealing it.
---@param win integer
local function restore(win)
  local saved = windows[win]
  if saved and vim.api.nvim_win_is_valid(win) then
    vim.wo[win][0].conceallevel = saved.level
    vim.wo[win][0].concealcursor = saved.cursor
  end
  windows[win] = nil
end

---Keep the cursor line masked in normal, insert, visual and command modes.
---@param win integer
local function protect(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if not enabled[vim.api.nvim_win_get_buf(win)] then
    restore(win)
    return
  end
  if not windows[win] then
    windows[win] = {
      level = vim.wo[win].conceallevel,
      cursor = vim.wo[win].concealcursor,
    }
  end
  vim.wo[win][0].conceallevel = 2
  vim.wo[win][0].concealcursor = 'nvic'
end

---Find a closing quote, respecting backslash escapes in double quotes.
---@param line string
---@param start integer One-based byte offset
---@param quote string
---@return boolean
local function closes_quote(line, start, quote)
  local col = start
  while col <= #line do
    local char = line:sub(col, col)
    if char == quote then
      return true
    end
    col = col + (char == '\\' and quote == '"' and 2 or 1)
  end
  return false
end

---Refresh only attached buffers. Conceal each UTF-8 character separately
---so values retain their length, including when wrapped or scrolled.
---@param buf integer
local function refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not enabled[buf] then
    return
  end
  local quote = nil ---@type string?
  local continuation = false
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local start = nil ---@type integer?
    if quote or continuation then
      start = 1
      if quote and closes_quote(line, 1, quote) then
        quote = nil
      end
    elseif not line:match('^%s*[#;]') then
      -- Also accepts export KEY=..., INI keys and npm registry auth keys.
      start = line:match('^%s*[^%s=]+%s*=%s*()')
        or line:match('^%s*export%s+[^%s=]+%s*=%s*()')
      if start then
        local char = line:sub(start, start)
        if
          (char == '"' or char == "'")
          and not closes_quote(line, start + 1, char)
        then
          quote = char
        end
      end
    end
    continuation = start ~= nil and line:match('\\%s*$') ~= nil
    local col = start and start - 1 or #line
    while col < #line do
      local next_col = col + 1
      -- Extmark columns are byte offsets; keep UTF-8 continuation bytes
      -- together so a multibyte character produces exactly one star.
      while next_col < #line do
        local byte = line:byte(next_col + 1)
        if byte < 128 or byte >= 192 then
          break
        end
        next_col = next_col + 1
      end
      vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
        end_col = next_col,
        conceal = '*',
        priority = 1000,
        right_gravity = false,
        end_right_gravity = true,
      })
      col = next_col
    end
  end
end

---Toggle visual masking for an attached buffer without changing its text.
---@param buf? integer Defaults to the current buffer
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if enabled[buf] == nil or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  enabled[buf] = not enabled[buf]
  refresh(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    protect(win)
  end
  vim.notify('Secret masking ' .. (enabled[buf] and 'enabled' or 'disabled'))
end

---Attach only to selected files; buffer callbacks update marks during edits.
---@param buf integer
local function attach(buf)
  if
    not vim.api.nvim_buf_is_valid(buf)
    or vim.bo[buf].buftype ~= ''
    or enabled[buf] ~= nil
  then
    return
  end
  enabled[buf] = true
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, changed_buf)
      refresh(changed_buf)
    end,
    on_reload = function(_, changed_buf)
      refresh(changed_buf)
    end,
    on_detach = function(_, detached_buf)
      enabled[detached_buf] = nil
    end,
  })
  vim.keymap.set('n', '<Leader>up', function()
    M.toggle(buf)
  end, { buffer = buf, desc = 'Toggle secret masking' })
  vim.api.nvim_buf_create_user_command(buf, 'SecretsToggle', function()
    M.toggle(buf)
  end, { desc = 'Toggle secret masking in this buffer' })
  refresh(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    protect(win)
  end
end

---Initialize lazily from filename triggers, including the triggering buffer.
---@param patterns string[] Autocommand filename patterns
---@param buf integer
function M.setup(patterns, buf)
  if not initialized then
    initialized = true
    local group = vim.api.nvim_create_augroup('my.secrets', {})
    vim.api.nvim_create_autocmd(
      { 'BufReadPost', 'BufNewFile', 'BufFilePost' },
      {
        group = group,
        pattern = patterns,
        callback = function(args)
          attach(args.buf)
        end,
      }
    )
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
      group = group,
      callback = function()
        protect(vim.api.nvim_get_current_win())
      end,
    })
    -- Splits and tabpages inherit the source window's concealed options.
    -- Preserve its original options so revealing/leaving the new window
    -- restores the user's settings, rather than our temporary overrides.
    vim.api.nvim_create_autocmd('WinLeave', {
      group = group,
      callback = function()
        inherited = windows[vim.api.nvim_get_current_win()]
      end,
    })
    vim.api.nvim_create_autocmd('WinNew', {
      group = group,
      callback = function()
        local win = vim.api.nvim_get_current_win()
        if vim.wo[win][0].concealcursor == 'nvic' then
          windows[win] = inherited
        end
        inherited = nil
        protect(win)
      end,
    })
    vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWinLeave' }, {
      group = group,
      callback = function()
        restore(vim.api.nvim_get_current_win())
      end,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = group,
      callback = function(args)
        windows[tonumber(args.match)] = nil
      end,
    })
  end
  attach(buf)
end

return M
