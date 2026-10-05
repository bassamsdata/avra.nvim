---@type my.pack.spec
return {
  src = 'https://github.com/bassamsdata/namu.nvim',
  data = {
    cmds = { 'Namu' },
    keys = {
      { lhs = '<leader>ss', opts = { desc = 'Namu symbols' } },
      { lhs = '<leader>sw', opts = { desc = 'Namu workspace' } },
      { lhs = '<leader>si', opts = { desc = 'Namu diagnostics' } },
      { lhs = '<leader>sI', opts = { desc = 'Namu workspace diagnostics' } },
      { lhs = '<leader>th', opts = { desc = 'Namu Themes' } },
    },
    -- Keep the development checkout as the source of running Namu code.
    load = function(spec, path)
      local dev_path = vim.fn.expand('~/repos/namu.nvim')
      if vim.uv.fs_stat(dev_path .. '/plugin/namu.lua') then
        path = dev_path
      end
      vim.opt.runtimepath:prepend(path)
      vim.cmd.source(path .. '/plugin/namu.lua')
      spec.data.postload(spec, path)
    end,
    postload = function()
      require('namu').setup({
        global = {
          jump = { enabled = true },
          movement = {
            next = { '<C-n>', '<C-j>', '<Down>' },
            previous = { '<C-p>', '<C-k>', '<Up>' },
          },
          display = {
            format = 'tree_guides',
          },
        },
      })

      vim.keymap.set('n', '<leader>th', '<cmd>Namu colorscheme<cr>', {
        desc = 'Namu themes',
        silent = true,
      })
      vim.keymap.set('n', '<leader>ss', '<cmd>Namu symbols<cr>', {
        desc = 'Jump to LSP symbol',
        silent = true,
      })
      vim.keymap.set('n', '<leader>sw', '<cmd>Namu workspace<cr>', {
        desc = 'LSP Symbols - Workspace',
        silent = true,
      })
      vim.keymap.set('n', '<leader>si', '<cmd>Namu diagnostics<cr>', {
        desc = 'Buffer diagnostics',
      })
      vim.keymap.set(
        'n',
        '<leader>sI',
        '<cmd>Namu diagnostics workspace<cr>',
        {
          desc = 'Workspace diagnostics',
        }
      )
    end,
  },
}
