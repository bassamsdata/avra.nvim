---@class my.winbar.api
local M = {}
local utils = require('my.plugin.winbar.utils')

---Toggle the internal winbar in the current window
---@return nil
function M.toggle()
  local win = vim.api.nvim_get_current_win()
  if vim.wo[win].winbar == '%{%v:lua._winbar()%}' then
    vim.w[win].winbar_no_attach = true
    vim.wo[win].winbar = ''
  elseif vim.w[win].winbar_no_attach then
    vim.w[win].winbar_no_attach = nil
    utils.bar.attach(vim.api.nvim_win_get_buf(win), win)
  end
end

---Toggle the internal winbar in all windows, preserving local toggles
---@return nil
function M.toggle_all()
  vim.g.winbar_hidden = not vim.g.winbar_hidden
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.g.winbar_hidden then
      if vim.wo[win].winbar == '%{%v:lua._winbar()%}' then
        vim.wo[win].winbar = ''
      end
    else
      utils.bar.attach(vim.api.nvim_win_get_buf(win), win)
    end
  end
end

---Get the winbar
---@param opts {win: integer?, buf: integer?}?
---@return my.winbar.bar?|table<integer, winbar.bar>|table<integer, table<integer, winbar.bar>>
function M.get_winbar(opts)
  return utils.bar.get(opts)
end

---Get current winbar
---@return my.winbar.bar?
function M.get_current_winbar()
  return utils.bar.get_current()
end

---Get winbar menu
--- - If `opts.win` is specified, return the winbar menu attached the window;
--- - If `opts.win` is not specified, return all opened winbar menus
---@param opts {win: integer?}?
---@return my.winbar.menu?
function M.get_winbar_menu(opts)
  return utils.menu.get(opts)
end

---Get current winbar menu
---@return my.winbar.menu?
function M.get_current_winbar_menu()
  return utils.menu.get_current()
end

---Goto the start of context
---If `count` is 0, goto the start of current context, or the start at
---prev context if cursor is already at the start of current context;
---If `count` is positive, goto the start of `count` prev context
---@param count integer? default vim.v.count
function M.goto_context_start(count)
  count = count or vim.v.count
  local bar = M.get_current_winbar()
  if not bar or not bar.components or vim.tbl_isempty(bar.components) then
    return
  end
  local current_sym = bar.components[#bar.components]
  if not current_sym.range then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  if
    count == 0
    and current_sym.range.start.line == cursor[1] - 1
    and current_sym.range.start.character == cursor[2]
  then
    count = count + 1
  end
  while count > 0 do
    count = count - 1
    local prev_sym = bar.components[current_sym.bar_idx - 1]
    if not prev_sym or not prev_sym.range then
      break
    end
    current_sym = prev_sym
  end
  current_sym:jump(false)
end

---Open the menu of current context to select the next context
function M.select_next_context()
  local bar = M.get_current_winbar()
  if not bar or not bar.components or vim.tbl_isempty(bar.components) then
    return
  end
  bar:pick_mode_wrap(function()
    bar.components[#bar.components]:on_click()
  end)
end

---Pick a component from current winbar
---@param idx integer?
function M.pick(idx)
  local bar = M.get_current_winbar()
  if bar then
    bar:pick(idx)
  end
end

return M
