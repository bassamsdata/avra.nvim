---@class my.utils.contrast
local M = {}

---WCAG relative luminance for an opaque sRGB hex color.
---@param color string
---@return number
function M.luminance(color)
  assert(color:match('^#%x%x%x%x%x%x$'), 'expected an opaque RGB color')
  ---@param offset integer
  ---@return number
  local function channel(offset)
    local value = tonumber(color:sub(offset, offset + 1), 16) / 255
    return value <= 0.04045 and value / 12.92
      or ((value + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(2) + 0.7152 * channel(4) + 0.0722 * channel(6)
end

---@param foreground string
---@param background string
---@return number
function M.ratio(foreground, background)
  local a, b = M.luminance(foreground), M.luminance(background)
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

---Prefer theme colors that meet the target on every selection surface.
---@param backgrounds string[]
---@param candidates string[]
---@param minimum? number
---@return string, number
function M.foreground(backgrounds, candidates, minimum)
  assert(#backgrounds > 0 and #candidates > 0, 'expected color candidates')
  minimum = minimum or 4.5
  local best, score = candidates[1], 0
  for _, candidate in ipairs(candidates) do
    local worst = math.huge
    for _, background in ipairs(backgrounds) do
      worst = math.min(worst, M.ratio(candidate, background))
    end
    if worst >= minimum then
      return candidate, worst
    end
    if worst > score then
      best, score = candidate, worst
    end
  end
  return best, score
end

---Keep a background's hue while blending toward a readable endpoint.
---@param foreground string
---@param background string
---@param minimum? number
---@return string
function M.background(foreground, background, minimum)
  minimum = minimum or 4.5
  if M.ratio(foreground, background) >= minimum then
    return background
  end
  local endpoint = M.ratio(foreground, '#000000')
        > M.ratio(foreground, '#ffffff')
      and 0
    or 255
  ---@param amount number
  ---@return string
  local function blend(amount)
    local channels = {} ---@type integer[]
    for _, offset in ipairs({ 2, 4, 6 }) do
      local value = tonumber(background:sub(offset, offset + 1), 16)
      channels[#channels + 1] =
        math.floor(value + (endpoint - value) * amount + 0.5)
    end
    return string.format('#%02x%02x%02x', unpack(channels))
  end
  local low, high = 0, 1
  for _ = 1, 24 do
    local middle = (low + high) / 2
    if M.ratio(foreground, blend(middle)) >= minimum then
      high = middle
    else
      low = middle
    end
  end
  return blend(high)
end

return M
