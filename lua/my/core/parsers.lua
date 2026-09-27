---@class my.parsers
local M = {}

---@type string[]
M.languages = {
  'lua',
  'luadoc',
  'luap',
  'vim',
  'vimdoc',
  'query',
  'python',
  'bash',
  'json',
  'yaml',
  'toml',
  'markdown',
  'markdown_inline',
  'c',
  'cpp',
  'go',
  'rust',
  'r',
  'javascript',
  'typescript',
  'tsx',
  'html',
  'css',
  'regex',
  'diff',
}

---Install baseline parsers, then enable highlighting in already open buffers.
---@return nil
function M.setup()
  local ts = require('nvim-treesitter')
  ts.setup({ install_dir = vim.fn.stdpath('data') .. '/site' })
  ts.install(M.languages):await(vim.schedule_wrap(function(err, success)
    if err or success == false then
      vim.notify(
        'Parser install failed: '
          .. tostring(err or 'see :messages; restart to retry'),
        vim.log.levels.ERROR
      )
      return
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
        pcall(vim.treesitter.start, buf)
      end
    end
  end))
end

return M
