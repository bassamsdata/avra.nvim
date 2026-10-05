---@class my.appearance.managed
local M = {}
local fs = require('my.utils.fs')

---@param path string
---@param content string
---@return boolean
function M.write(path, content)
  if fs.read_file(path) == content then
    return true
  end
  local temporary = path .. '.avra-' .. vim.fn.getpid() .. '.tmp'
  local stat = vim.uv.fs_stat(path)
  local fd = vim.uv.fs_open(temporary, 'w', stat and stat.mode or 384)
  if not fd then
    return false
  end
  local written = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  if written ~= #content or not vim.uv.fs_rename(temporary, path) then
    vim.uv.fs_unlink(temporary)
    return false
  end
  return true
end

---@param content string
---@param name string
---@return string?, string?, string?
local function split(content, name)
  local first = '\n# Avra ' .. name .. ' theme begin '
  local last = '# Avra ' .. name .. ' theme end\n'
  local start_at = content:find(first, 1, true)
  local end_at = content:find(last, 1, true)
  if (start_at and not end_at) or (end_at and not start_at) then
    return nil, nil, 'managed block was edited'
  end
  if not start_at then
    return content, '', nil
  end
  if end_at < start_at then
    return nil, nil, 'managed block markers are out of order'
  end
  local body_start = content:find('\n', start_at + #first, true)
  if not body_start or body_start >= end_at then
    return nil, nil, 'managed block header was edited'
  end
  local checksum = content:sub(start_at + #first, body_start - 1)
  local body = content:sub(body_start + 1, end_at - 1)
  if vim.fn.sha256(body) ~= checksum then
    return nil, nil, 'managed theme was edited; leaving it intact'
  end
  return content:sub(1, start_at - 1), content:sub(end_at + #last), nil
end

---@param path string
---@param name string
---@param body string
---@param conflicts string[] Lua patterns for existing section headers
---@return boolean, string?
function M.apply(path, name, body, conflicts)
  local current = fs.read_file(path)
  if current == nil then
    return false, 'could not read ' .. path
  end
  local before, after, err = split(current, name)
  if err then
    return false, err
  end
  local unmanaged = before .. after
  for line in (unmanaged .. '\n'):gmatch('(.-)\n') do
    for _, pattern in ipairs(conflicts) do
      if line:match(pattern) then
        return false, 'an existing theme section would conflict in ' .. path
      end
    end
  end
  local block = '\n# Avra '
    .. name
    .. ' theme begin '
    .. vim.fn.sha256(body)
    .. '\n'
    .. body
    .. '# Avra '
    .. name
    .. ' theme end\n'
  local updated = before .. block .. after
  if fs.read_file(path) ~= current or not M.write(path, updated) then
    return false, 'configuration changed or could not be written: ' .. path
  end
  return true
end

---@param path string
---@param name string
---@return boolean, string?
function M.reset(path, name)
  local current = fs.read_file(path)
  if current == nil then
    return true
  end
  local before, after, err = split(current, name)
  if err then
    return false, err
  end
  if before == current then
    return true
  end
  if not M.write(path, before .. after) then
    return false, 'could not restore ' .. path
  end
  return true
end

return M
