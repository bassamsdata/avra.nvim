---@class my.pack.res.codecompanion.zai
local M = {}

---Resolve credentials only when the adapter is used.
---@return string?
local function zai_api_key()
  for _, name in ipairs({ 'ZAI_API_KEY', 'ZAI', 'zai_api_key', 'zai' }) do
    if vim.env[name] and vim.env[name] ~= '' then
      return vim.env[name]
    end
  end
  if vim.fn.executable('api-pass') == 1 then
    local result = vim
      .system({ 'api-pass', 'show', 'zai', '--key' }, {
        text = true,
      })
      :wait()
    if result.code == 0 and result.stdout then
      local key = vim.trim(result.stdout)
      if key ~= '' then
        return key
      end
    end
  end
  return vim.fn.inputsecret('Z.ai API key: ')
end

---Retain the default config's Z.ai model and reasoning compatibility.
---@return CodeCompanion.HTTPAdapter
function M.adapter()
  return require('codecompanion.adapters').extend('openai', {
    name = 'zai',
    formatted_name = 'Z.AI',
    url = 'https://api.z.ai/api/coding/paas/v4/chat/completions',

    env = {
      api_key = zai_api_key,
    },
    schema = {
      model = {
        default = 'glm-5.3-flash',
        choices = {
          'glm-4.7',
          'glm-5',
          'glm-5-turbo',
          'glm-5.1',
          'glm-5.2',
          'glm-5.3-flash',
          'glm-5.3',
        },
      },
      thinking = {
        default = {
          type = 'enabled',
          clear_thinking = false,
        },
        mapping = 'parameters',
      },
    },
    handlers = {
      ---@param self CodeCompanion.HTTPAdapter
      ---@param messages table
      ---@return table
      form_messages = function(self, messages)
        local openai = require('codecompanion.adapters.http.openai')
        local result = openai.handlers.form_messages(self, messages)

        for _, msg in ipairs(result.messages) do
          if msg.reasoning then
            msg.reasoning_content = msg.reasoning.content
            msg.reasoning = nil
          end
        end
        return result
      end,

      ---@param _ CodeCompanion.HTTPAdapter
      ---@param data table
      ---@return table
      parse_message_meta = function(_, data)
        local extra = data.extra
        if extra and extra.reasoning_content then
          data.output.reasoning = { content = extra.reasoning_content }
          if data.output.content == '' then
            data.output.content = nil
          end
        end
        return data
      end,
    },
  })
end

return M
