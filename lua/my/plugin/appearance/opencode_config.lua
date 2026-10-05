---@class my.appearance.opencode_config
local M = {}

---@class my.appearance.opencode_config.token
---@field text string
---@field first integer
---@field last integer

---Validate JSONC while retaining byte positions, comments, and formatting.
---@param content string
---@return my.appearance.opencode_config.token[]?, string?
local function tokens(content)
  local result = {} ---@type my.appearance.opencode_config.token[]
  local cleaned = {} ---@type string[]
  local pos = 1
  while pos <= #content do
    local first = pos
    local char = content:sub(pos, pos)
    local pair = content:sub(pos, pos + 1)
    if char:match('%s') then
      pos = pos + 1
      cleaned[#cleaned + 1] = char
    elseif pair == '//' or pair == '/*' then
      local last = pair == '//'
          and (content:find('\n', pos + 2, true) or #content + 1)
        or content:find('*/', pos + 2, true)
      if not last then
        return nil, 'unterminated JSONC comment'
      end
      pos = pair == '//' and last or last + 2
      cleaned[#cleaned + 1] = string.rep(' ', pos - first)
    else
      if char == '"' then
        pos = pos + 1
        while pos <= #content do
          local current = content:sub(pos, pos)
          pos = pos + (current == '\\' and 2 or 1)
          if current == '"' then
            break
          end
        end
      elseif char:match('[{}%[%]:,]') then
        pos = pos + 1
      else
        while
          pos <= #content
          and not content:sub(pos, pos):match('[%s{}%[%]:,/]')
        do
          pos = pos + 1
        end
        if pos == first then
          return nil, 'invalid JSONC token'
        end
      end
      local value = content:sub(first, pos - 1)
      result[#result + 1] = { text = value, first = first, last = pos - 1 }
      cleaned[#cleaned + 1] = value
    end
  end
  local plain = table.concat(cleaned)
  for i, token in ipairs(result) do
    local next_token = result[i + 1]
    if
      token.text == ','
      and next_token
      and (next_token.text == '}' or next_token.text == ']')
    then
      plain = plain:sub(1, token.first - 1) .. ' ' .. plain:sub(token.last + 1)
    end
  end
  local ok, decoded = pcall(vim.json.decode, plain)
  if not ok or type(decoded) ~= 'table' or not result[1] then
    return nil, 'invalid TUI configuration'
  end
  if result[1].text ~= '{' then
    return nil, 'TUI configuration must be an object'
  end
  return result
end

---Read or replace only the top-level theme; nil removes the property.
---@param content string
---@param replace boolean
---@param value string?
---@return string?, string?, string? updated content, old theme, error
function M.theme(content, replace, value)
  local list, err = tokens(content)
  if not list then
    return nil, nil, err
  end
  local depth = 0
  local found ---@type integer?
  for i, token in ipairs(list) do
    if token.text == '{' or token.text == '[' then
      depth = depth + 1
    elseif token.text == '}' or token.text == ']' then
      depth = depth - 1
    elseif depth == 1 and token.text:sub(1, 1) == '"' then
      local key = vim.json.decode(token.text)
      if key == 'theme' and list[i + 1].text == ':' then
        if found then
          return nil, nil, 'duplicate theme properties'
        end
        found = i
      end
    end
  end
  local old ---@type string?
  if found then
    local token = list[found + 2]
    if token.text:sub(1, 1) ~= '"' then
      return nil, nil, 'theme must be a string'
    end
    old = vim.json.decode(token.text)
    if replace then
      local first, last = token.first, token.last
      local replacement = value and vim.json.encode(value) or ''
      if not value then
        first = list[found].first
        if list[found + 3].text == ',' then
          last = list[found + 3].last
        elseif list[found - 1].text == ',' then
          first = list[found - 1].first
        end
      end
      content = content:sub(1, first - 1)
        .. replacement
        .. content:sub(last + 1)
    end
  elseif replace and value then
    local first = list[1].last
    local field = '\n  "theme": ' .. vim.json.encode(value)
    local comma = list[2].text ~= '}' and ',' or ''
    content = content:sub(1, first)
      .. field
      .. comma
      .. '\n'
      .. content:sub(first + 1)
  end
  return content, old, nil
end

return M
