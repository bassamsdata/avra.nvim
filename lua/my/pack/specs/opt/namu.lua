return {
  src = 'https://github.com/bassamsdata/namu.nvim',
  data = {
    cmds = { 'Namu' },
    keys = {
      { lhs = '<leader>ss', opts = { desc = 'Namu symbols' } },
      { lhs = '<leader>sw', opts = { desc = 'Namu workspace' } },
      { lhs = '<leader>si', opts = { desc = 'Namu diagnostics' } },
      { lhs = '<leader>sI', opts = { desc = 'Namu workspace diagnostics' } },
    },
    postload = function()
      require('namu').setup({
        global = {
          -- jump = { enabled = true }, -- opt-in: one-key jump labels, toggle with `;`
          movement = {
            next = { '<C-n>', '<C-j>', '<Down>' },
            previous = { '<C-p>', '<C-k>', '<Up>' },
          },
          display = {
            format = 'tree_guides',
          },
        },
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
