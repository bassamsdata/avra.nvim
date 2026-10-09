---@class my.plugin.special_buffers
local M = {}

---Close a view without discarding changes or quitting the last window.
---@param win? integer
---@param fallback_buf? integer
---@return boolean
function M.close(win, fallback_buf)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].modified then
    vim.notify('Save changes before closing this buffer.', vim.log.levels.WARN)
    return false
  end
  local ok, err = pcall(function()
    local tab = vim.api.nvim_win_get_tabpage(win)
    local normal_wins = 0
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_config(candidate).relative == '' then
        normal_wins = normal_wins + 1
      end
    end
    if
      vim.api.nvim_win_get_config(win).relative ~= ''
      or normal_wins > 1
      or #vim.api.nvim_list_tabpages() > 1
    then
      vim.api.nvim_win_close(win, false)
      return
    end
    if
      not fallback_buf
      or fallback_buf == buf
      or not vim.api.nvim_buf_is_valid(fallback_buf)
    then
      fallback_buf = nil
      for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
        if
          candidate ~= buf
          and vim.bo[candidate].buflisted
          and vim.bo[candidate].buftype == ''
        then
          fallback_buf = candidate
          break
        end
      end
    end
    vim.api.nvim_win_set_buf(
      win,
      fallback_buf or vim.api.nvim_create_buf(true, false)
    )
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
  return ok
end

---Use a local mapping so normal files keep macro recording on q.
---@param buf integer
---@return nil
function M.map_close(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.keymap.set('n', 'q', function()
    M.close()
  end, { buffer = buf, desc = 'Close special buffer' })
end

---@return nil
function M.setup()
  local group = vim.api.nvim_create_augroup('my.special_buffers', {})
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = {
      'help',
      'qf',
      'man',
      'checkhealth',
      'fugitive',
      'fugitiveblame',
    },
    callback = function(args)
      M.map_close(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'FugitivePager',
    callback = function(args)
      if not vim.bo[args.buf].modifiable then
        M.map_close(args.buf)
      end
    end,
  })
end

return M
