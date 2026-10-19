---@type my.pack.spec
return {
  src = 'https://github.com/esmuellert/codediff.nvim',
  data = {
    cmds = 'CodeDiff',
    keys = {
      { lhs = '<Leader>gnd', opts = { desc = 'CodeDiff repository changes' } },
      { lhs = '<Leader>gnD', opts = { desc = 'CodeDiff staged changes' } },
    },
    postload = function()
      require('codediff').setup({})

      -- stylua: ignore start
      vim.keymap.set('n', '<Leader>gnd', '<Cmd>CodeDiff<CR>',          { desc = 'CodeDiff repository changes' })
      vim.keymap.set('n', '<Leader>gnD', '<Cmd>CodeDiff --staged<CR>', { desc = 'CodeDiff staged changes' })
      -- stylua: ignore end
    end,
  },
}
