---@class my.tools
local M = {}

---@type string[]
M.packages = {
  'lua-language-server',
  'ty',
  'pyrefly',
  'ruff',
  'stylua',
  'efm',
}

---Install missing baseline tools and attach servers to open files afterwards.
---@return nil
function M.setup()
  local registry = require('mason-registry')
  local missing = vim.tbl_filter(function(name)
    return not registry.is_installed(name)
  end, M.packages)
  if #missing == 0 then
    return
  end
  registry.refresh(vim.schedule_wrap(function(ok)
    if not ok then
      vim.notify(
        'Mason registry failed; restart to retry.',
        vim.log.levels.ERROR
      )
      return
    end
    for _, name in ipairs(missing) do
      local found, pkg = pcall(registry.get_package, name)
      if not found then
        vim.notify('Mason package unavailable: ' .. name, vim.log.levels.ERROR)
      elseif not pkg:is_installed() and not pkg:is_installing() then
        pkg:install(
          {},
          vim.schedule_wrap(function(success)
            if not success then
              vim.notify(
                'Install failed: ' .. name .. '. See :MasonLog.',
                vim.log.levels.ERROR
              )
              return
            end
            -- FileType may already have fired before the executable existed.
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if
                vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ''
              then
                vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
              end
            end
          end)
        )
      end
    end
  end))
end

return M
