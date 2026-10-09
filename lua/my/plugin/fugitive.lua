---@class my.plugin.fugitive
local M = {}

---@class my.fugitive.origin
---@field win integer
---@field buf integer

---Close status and return to the window that opened it.
---@param win? integer
---@return boolean
function M.close(win)
  local origin = vim.t.my_fugitive_origin ---@type my.fugitive.origin?
  if
    not require('my.plugin.special_buffers').close(win, origin and origin.buf)
  then
    return false
  end
  if
    origin
    and vim.api.nvim_win_is_valid(origin.win)
    and vim.api.nvim_win_get_tabpage(origin.win)
      == vim.api.nvim_get_current_tabpage()
  then
    vim.api.nvim_set_current_win(origin.win)
  end
  vim.t.my_fugitive_origin = nil
  return true
end

---Toggle this repository's visible status windows in the current tab.
---@return nil
function M.toggle()
  local ok, git_dir = pcall(vim.fn.FugitiveGitDir)
  if not ok then
    vim.notify(tostring(git_dir), vim.log.levels.WARN)
    return
  end
  local windows = {} ---@type integer[]
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'fugitive' then
      local found, dir = pcall(vim.fn.FugitiveGitDir, buf)
      if found and (git_dir == '' or dir == git_dir) then
        windows[#windows + 1] = win
      end
    end
  end
  if #windows > 0 then
    for _, win in ipairs(windows) do
      if not M.close(win) then
        return
      end
    end
    return
  end
  local origin = {
    win = vim.api.nvim_get_current_win(),
    buf = vim.api.nvim_get_current_buf(),
  } ---@type my.fugitive.origin
  local opened, err = pcall(vim.cmd.Git)
  if not opened then
    vim.notify(tostring(err), vim.log.levels.WARN)
    return
  end
  vim.t.my_fugitive_origin = origin
end

return M
