---@type my.pack.spec
return {
  src = 'https://github.com/joryeugene/dadbod-grip.nvim',
  data = {
    cmds = {
      'Grip',
      'GripConnect',
      'GripQuery',
      'GripStart',
    },
    keys = {
      {
        lhs = '<leader>db',
        opts = { desc = 'Database connections' },
      },
    },
    postload = function()
      require('dadbod-grip').setup({})

      vim.keymap.set('n', '<leader>db', '<cmd>GripConnect<cr>', {
        desc = 'Database connections',
      })
    end,
  },
}
