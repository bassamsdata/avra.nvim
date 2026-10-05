---@type my.pack.spec
return {
  src = 'https://github.com/mason-org/mason.nvim',
  version = vim.version.range('^2'),
  data = {
    cmds = {
      'Mason',
      'MasonInstall',
      'MasonUninstall',
      'MasonUninstallAll',
      'MasonUpdate',
      'MasonLog',
    },
    events = { 'FileType' },
    postload = function()
      require('mason').setup()
      require('my.core.tools').setup()
    end,
  },
}
