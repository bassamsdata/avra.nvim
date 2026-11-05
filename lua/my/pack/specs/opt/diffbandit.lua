---@type my.pack.spec
return {
  src = 'https://github.com/CoreyKaylor/diffbandit.nvim',
  data = {
    cmds = {
      'DiffBandit',
      'DiffBanditBuffers',
      'DiffBanditGit',
      'DiffBanditGitCurrent',
      'DiffBanditCommitPanel',
      'DiffBanditGitMenu',
      'DiffBanditGitLog',
      'DiffBanditGitCommit',
      'DiffBanditGitCompare',
      'DiffBanditGitCheckout',
      'DiffBanditMerge',
      'DiffBanditFolderDiff',
      'DiffBanditClose',
      'DiffBanditLaunch',
      'DiffBanditToggleStageHunk',
      'DiffBanditStageHunk',
      'DiffBanditUnstageHunk',
      'DiffBanditDiscardHunk',
      'DiffBanditApplyLeftHunk',
      'DiffBanditApplyRightHunk',
      'DiffBanditUndo',
    },
    keys = {
      {
        lhs = '<Leader>gvv',
        opts = { desc = 'DiffBandit repository changes' },
      },
      { lhs = '<Leader>gvf', opts = { desc = 'DiffBandit current file' } },
      { lhs = '<Leader>gvs', opts = { desc = 'DiffBandit staged changes' } },
      { lhs = '<Leader>gvc', opts = { desc = 'DiffBandit commit panel' } },
      { lhs = '<Leader>gvm', opts = { desc = 'DiffBandit Git menu' } },
      { lhs = '<Leader>gvq', opts = { desc = 'DiffBandit close view' } },
    },
    postload = function()
      require('diffbandit').setup({
        -- Preserve Space as leader and [d/]d for diagnostics in diff panes.
        navigation = {
          document_keys = { top = 'gzt', bottom = 'gzb' },
          snap_key = 'gzs',
        },
        actions = {
          keys = { toggle_stage = '<Leader>gvt', undo = 'gzu' },
        },
        git = {
          panel = {
            keys = {
              toggle_stage = '<Leader>gvt',
              toggle_amend = '<Leader>gvA',
              focus_panel = '<Leader>gvc',
            },
          },
        },
        merge = {
          keys = { focus_panel = '<Leader>gvc', snap = 'gzs' },
        },
        folder = { keys = { toggle_expand = '<Leader>gve' } },
      })

      -- stylua: ignore start
      vim.keymap.set('n', '<Leader>gvv', '<Cmd>DiffBanditGit<CR>',          { desc = 'DiffBandit repository changes' })
      vim.keymap.set('n', '<Leader>gvf', '<Cmd>DiffBanditGitCurrent<CR>',   { desc = 'DiffBandit current file' })
      vim.keymap.set('n', '<Leader>gvs', '<Cmd>DiffBanditGit --staged<CR>', { desc = 'DiffBandit staged changes' })
      vim.keymap.set('n', '<Leader>gvc', '<Cmd>DiffBanditCommitPanel<CR>',  { desc = 'DiffBandit commit panel' })
      vim.keymap.set('n', '<Leader>gvm', '<Cmd>DiffBanditGitMenu<CR>',      { desc = 'DiffBandit Git menu' })
      vim.keymap.set('n', '<Leader>gvq', '<Cmd>DiffBanditClose<CR>',        { desc = 'DiffBandit close view' })
      -- stylua: ignore end
    end,
  },
}
