---@type my.pack.spec
return {
  src = 'https://github.com/NeogitOrg/neogit',
  data = {
    cmds = {
      'Neogit',
      'NeogitCommit',
      'NeogitLogCurrent',
      'NeogitResetState',
    },
    keys = {
      { lhs = '<Leader>gnn', opts = { desc = 'Neogit status' } },
      { lhs = '<Leader>gnc', opts = { desc = 'Neogit commit popup' } },
      { lhs = '<Leader>gnb', opts = { desc = 'Neogit branch popup' } },
      { lhs = '<Leader>gnl', opts = { desc = 'Neogit log popup' } },
      { lhs = '<Leader>gns', opts = { desc = 'Neogit stash popup' } },
    },
    deps = {
      'https://github.com/esmuellert/codediff.nvim',
      -- Reuse the existing Snacks picker for Neogit's selections.
      'https://github.com/folke/snacks.nvim',
    },
    postload = function()
      require('neogit').setup({
        kind = 'tab',
        integrations = { codediff = true, snacks = true },
        diff_viewer = 'codediff',
      })

      -- stylua: ignore start
      vim.keymap.set('n', '<Leader>gnn', '<Cmd>Neogit<CR>',        { desc = 'Neogit status' })
      vim.keymap.set('n', '<Leader>gnc', '<Cmd>Neogit commit<CR>', { desc = 'Neogit commit popup' })
      vim.keymap.set('n', '<Leader>gnb', '<Cmd>Neogit branch<CR>', { desc = 'Neogit branch popup' })
      vim.keymap.set('n', '<Leader>gnl', '<Cmd>Neogit log<CR>',    { desc = 'Neogit log popup' })
      vim.keymap.set('n', '<Leader>gns', '<Cmd>Neogit stash<CR>',  { desc = 'Neogit stash popup' })
      -- stylua: ignore end
    end,
  },
}
