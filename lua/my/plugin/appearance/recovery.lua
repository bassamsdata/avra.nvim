---@class my.appearance.recovery
local M = {}
local fs = require('my.utils.fs')
local managed = require('my.plugin.appearance.managed')

---Migrate app-local journals to the tool's shared configuration directory.
---@param path string Shared journal path
---@param legacy_name string Filename used in Neovim's state directory
---@param accepts fun(content: string): boolean Validate the target and fields
---@return string?, string? content, error
function M.read(path, legacy_name, accepts)
  local current = fs.read_file(path)
  if current then
    return current, nil
  end
  local state_dir = vim.fn.stdpath('state')
  local root = vim.fs.dirname(state_dir)
  local legacy = {} ---@type table<string, string>
  local content ---@type string?
  for name, kind in vim.fs.dir(root) do
    if kind == 'directory' then
      local candidate = vim.fs.joinpath(root, name, legacy_name)
      local saved = fs.read_file(candidate)
      if saved and accepts(saved) then
        if
          content
          and not vim.deep_equal(
            vim.json.decode(content),
            vim.json.decode(saved)
          )
        then
          return nil, 'conflicting recovery states for ' .. path
        end
        content = saved
        legacy[candidate] = saved
      elseif
        saved and candidate == vim.fs.joinpath(state_dir, legacy_name)
      then
        return nil, 'invalid recovery state: ' .. candidate
      end
    end
  end
  if not content then
    return nil, nil
  end
  -- A different editor may have installed the shared journal during discovery.
  current = fs.read_file(path)
  if current then
    return current, nil
  end
  if
    not pcall(vim.fn.mkdir, vim.fs.dirname(path), 'p')
    or not managed.write(path, content)
  then
    return nil, 'could not migrate recovery state to ' .. path
  end
  for candidate, saved in pairs(legacy) do
    if fs.read_file(candidate) == saved then
      vim.uv.fs_unlink(candidate)
    end
  end
  return content, nil
end

return M
