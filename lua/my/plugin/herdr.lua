---@class my.plugin.herdr
local M = {}

---@alias my.herdr.direction 'h'|'j'|'k'|'l'
---@alias my.herdr.pane_direction 'left'|'down'|'up'|'right'
---@type table<my.herdr.direction, my.herdr.pane_direction>
local directions = { h = 'left', j = 'down', k = 'up', l = 'right' }
local pending = false

---@return boolean
function M.available()
  return vim.env.HERDR_ENV == '1'
    and vim.env.HERDR_PANE_ID ~= nil
    and vim.env.HERDR_PANE_ID ~= ''
end

---Move locally first; only contact Herdr at a Neovim window boundary.
---@param direction my.herdr.direction
---@return nil
function M.navigate(direction)
  if vim.fn.getcmdwintype() ~= '' then
    return
  end
  local win = vim.api.nvim_get_current_win()
  local ok, err = pcall(vim.cmd.wincmd, direction)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
    return
  end
  if vim.api.nvim_get_current_win() ~= win or not M.available() then
    return
  end
  if pending then
    return
  end
  pending = true
  local started, result = pcall(
    vim.system,
    {
      vim.env.HERDR_BIN_PATH or 'herdr',
      'pane',
      'focus',
      '--direction',
      directions[direction],
      '--current',
    },
    { text = true, timeout = 1000 },
    vim.schedule_wrap(function(out)
      pending = false
      if out.code ~= 0 then
        vim.notify(
          'Herdr navigation: ' .. (out.stderr or 'could not focus pane'),
          vim.log.levels.WARN
        )
      end
    end)
  )
  if not started then
    pending = false
    vim.notify('Herdr navigation: ' .. tostring(result), vim.log.levels.WARN)
  end
end

---Buffer-local mappings take priority over plugin navigation shortcuts.
---@param buf? integer
---@return nil
local function map_keys(buf)
  if buf and not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  for direction, name in pairs(directions) do
    vim.keymap.set(
      { 'n', 'x', 'i', 't' },
      '<C-' .. direction .. '>',
      function()
        M.navigate(direction)
      end,
      {
        buffer = buf,
        desc = 'Go ' .. name .. ' between Neovim windows or Herdr panes',
      }
    )
  end
end

---Install only in Herdr; preserve ordinary editor shortcuts elsewhere.
---@return nil
function M.setup()
  if not M.available() then
    return
  end
  map_keys()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    map_keys(buf)
  end
  local group = vim.api.nvim_create_augroup('my.herdr.navigation', {})
  vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
    group = group,
    callback = vim.schedule_wrap(function(args)
      map_keys(args.buf)
    end),
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'FugitiveIndex', 'FugitiveObject', 'FugitivePager' },
    callback = vim.schedule_wrap(function(args)
      map_keys(args.buf)
    end),
  })
end

return M
