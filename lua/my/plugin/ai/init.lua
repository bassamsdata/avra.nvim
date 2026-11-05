---@class my.plugin.ai
local M = {}

---@alias my.ai.provider 'codex'|'glm'|'openrouter'

---@class my.ai.launcher
---@field command string
---@field label string
---@field config? string

---@type table<my.ai.provider, my.ai.launcher>
local providers = {
  codex = { command = 'cx', label = 'Codex (OpenAI)' },
  glm = {
    command = 'glm',
    label = 'GLM (Z.ai)',
    config = '~/.codex-glm/glm.config.toml',
  },
  openrouter = {
    command = 'cxo',
    label = 'OpenRouter',
    config = '~/.codex-openrouter/config.toml',
  },
}

---@type my.ai.provider[]
local provider_names = { 'codex', 'glm', 'openrouter' }

---Find the current file's project, including when launched from a terminal.
---@return string
local function project_root()
  if vim.b.my_ai_cwd then
    return vim.b.my_ai_cwd
  end
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= '' or path == '' then
    path = vim.fn.getcwd()
  end
  return require('my.utils.fs').root(path) or vim.fn.getcwd()
end

---Open an agent in a terminal split at the current project root.
---@param provider my.ai.provider
---@param cwd? string
---@return nil
function M.open(provider, cwd)
  local spec = providers[provider]
  if not spec then
    vim.notify(
      'AI provider must be codex, glm, or openrouter',
      vim.log.levels.WARN
    )
    return
  end
  if vim.fn.executable('codex') ~= 1 then
    vim.notify('Install Codex CLI before opening AI', vim.log.levels.WARN)
    return
  end

  local launcher = vim.fn.expand('~/.local/bin/' .. spec.command)
  if vim.fn.executable(launcher) ~= 1 then
    vim.notify('Missing AI launcher: ' .. launcher, vim.log.levels.WARN)
    return
  end
  if spec.config then
    local config = vim.fn.expand(spec.config)
    if vim.fn.filereadable(config) ~= 1 then
      vim.notify('Missing AI configuration: ' .. config, vim.log.levels.WARN)
      return
    end
  end

  cwd = cwd or project_root()
  -- A list command keeps paths and arguments out of the shell parser.
  vim.cmd('botright vnew')
  local buf = vim.api.nvim_get_current_buf()
  local ok, job = pcall(vim.fn.jobstart, { launcher }, {
    term = true,
    cwd = cwd,
  })
  if not ok or job <= 0 then
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.notify('Could not start AI terminal', vim.log.levels.WARN)
    return
  end
  vim.bo[buf].bufhidden = 'hide'
  vim.b[buf].my_ai_cwd = cwd
  vim.cmd.startinsert()
end

---Choose the agent before opening its terminal.
---@return nil
function M.select()
  local cwd = project_root()
  vim.ui.select(provider_names, {
    prompt = 'Open AI',
    ---@param provider my.ai.provider
    ---@return string
    format_item = function(provider)
      return providers[provider].label
    end,
  }, function(provider)
    if provider then
      M.open(provider, cwd)
    end
  end)
end

---Register the optional-provider command on first use.
---@return nil
function M.setup()
  vim.api.nvim_create_user_command('AI', function(args)
    if args.args == '' then
      M.select()
    else
      M.open(args.args)
    end
  end, {
    nargs = '?',
    desc = 'Open Codex, GLM, or OpenRouter at the current project root',
    ---@param lead string
    ---@return string[]
    complete = function(lead)
      return vim.tbl_filter(function(provider)
        return vim.startswith(provider, lead)
      end, provider_names)
    end,
  })
end

return M
