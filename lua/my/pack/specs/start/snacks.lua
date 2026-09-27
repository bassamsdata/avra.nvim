---@type my.pack.spec
return {
  src = 'https://github.com/folke/snacks.nvim',
  data = {
    deps = {
      {
        src = 'https://github.com/kyazdani42/nvim-web-devicons',
        data = { optional = true },
      },
    },
    cmds = 'Snacks',
    keys = {
      -- stylua: ignore start
      { lhs = '<Leader>.', opts = { desc = 'Find files' } },
      { lhs = "<Leader>'", opts = { desc = 'Resume last picker' } },
      { lhs = '<Leader>`', opts = { desc = 'Find marks' } },
      { lhs = '<Leader>,', opts = { desc = 'Find buffers' } },
      { lhs = '<Leader>/', opts = { desc = 'Grep' } },
      { lhs = '<Leader>?', opts = { desc = 'Find help files' } },
      { lhs = '<Leader>*', mode = { 'n', 'x' }, opts = { desc = 'Grep word under cursor' } },
      { lhs = '<Leader>#', mode = { 'n', 'x' }, opts = { desc = 'Grep word under cursor' } },
      { lhs = '<Leader>"', opts = { desc = 'Find registers' } },
      { lhs = '<Leader>:', opts = { desc = 'Find commands' } },
      { lhs = '<Leader>F', opts = { desc = 'Find all available pickers' } },
      { lhs = '<Leader>o', opts = { desc = 'Find oldfiles' } },
      { lhs = '<Leader>-', opts = { desc = 'Find lines in buffer' } },
      { lhs = '<Leader>-', opts = { desc = 'Find lines in selection' }, mode = 'x' },
      { lhs = '<Leader>=', opts = { desc = 'Find lines across buffers' } },
      { lhs = '<Leader>n', opts = { desc = 'Find treesitter nodes' } },
      { lhs = '<Leader>R', opts = { desc = 'Find symbol locations' } },
      { lhs = '<Leader>f*', mode = { 'n', 'x' }, opts = { desc = 'Grep word under cursor' } },
      { lhs = '<Leader>f#', mode = { 'n', 'x' }, opts = { desc = 'Grep word under cursor' } },
      { lhs = '<Leader>f:', opts = { desc = 'Find commands' } },
      { lhs = '<Leader>f/', opts = { desc = 'Grep' } },
      { lhs = '<Leader>fH', opts = { desc = 'Find highlights' } },
      { lhs = "<Leader>f'", opts = { desc = 'Resume last picker' } },
      { lhs = '<Leader>fA', opts = { desc = 'Find autocmds' } },
      { lhs = '<Leader>fb', opts = { desc = 'Find buffers' } },
      { lhs = '<Leader>fd', opts = { desc = 'Find document diagnostics' } },
      { lhs = '<Leader>fD', opts = { desc = 'Find workspace diagnostics' } },
      { lhs = '<Leader>ff', opts = { desc = 'Find files' } },
      { lhs = '<Leader>fl', opts = { desc = 'Find location list' } },
      { lhs = '<Leader>fq', opts = { desc = 'Find quickfix list' } },
      { lhs = '<Leader>ft', opts = { desc = 'Find tags' } },
      { lhs = '<Leader>fgs', opts = { desc = 'Find git stash' } },
      { lhs = '<Leader>fgg', opts = { desc = 'Find git status' } },
      { lhs = '<Leader>fgL', opts = { desc = 'Find git logs' } },
      { lhs = '<Leader>fgl', opts = { desc = 'Find git buffer logs' } },
      { lhs = '<Leader>fgb', opts = { desc = 'Find git branches' } },
      { lhs = '<Leader>fgf', opts = { desc = 'Find git files' } },
      { lhs = '<Leader>fgF', opts = { desc = 'Find git commits containing file' } },
      { lhs = '<Leader>fh', opts = { desc = 'Find help files' } },
      { lhs = '<Leader>fk', opts = { desc = 'Find keymaps' } },
      { lhs = '<Leader>fm', opts = { desc = 'Find marks' } },
      { lhs = '<Leader>fo', opts = { desc = 'Find oldfiles' } },
      { lhs = '<Leader>fz', opts = { desc = 'Find directories from z' } },
      { lhs = '<Leader>fw', opts = { desc = 'Find sessions (workspaces)' } },
      { lhs = '<Leader>fn', opts = { desc = 'Find treesitter nodes' } },
      { lhs = '<Leader>fs', opts = { desc = 'Find lsp symbols or treesitter nodes' } },
      { lhs = '<Leader>fSd', opts = { desc = 'Find symbol definitions' } },
      { lhs = '<Leader>fSD', opts = { desc = 'Find symbol declarations' } },
      { lhs = '<Leader>fS<C-d>', opts = { desc = 'Find symbol type definitions' } },
      { lhs = '<Leader>fSs', opts = { desc = 'Find symbol in current document' } },
      { lhs = '<Leader>fSS', opts = { desc = 'Find symbol in whole workspace' } },
      { lhs = '<Leader>fSi', opts = { desc = 'Find symbol implementations' } },
      { lhs = '<Leader>fS<', opts = { desc = 'Find symbol incoming calls' } },
      { lhs = '<Leader>fS>', opts = { desc = 'Find symbol outgoing calls' } },
      { lhs = '<Leader>fSr', opts = { desc = 'Find symbol references' } },
      -- stylua: ignore end
    },
    init = function(spec, path)
      -- Lazy-load snacks on the first `vim.ui.select()` call, then let snacks
      -- (with `picker.ui_select = true`) register its own implementation
      local ui_select = vim.ui.select

      local function select_wrapper(...)
        require('my.utils.pack').load(spec, path)
        -- Fall back to the original `vim.ui.select()` if loading failed
        if vim.ui.select == select_wrapper then
          vim.ui.select = ui_select
        end
        vim.ui.select(...)
      end

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = select_wrapper
    end,
    postload = function()
      local Snacks = require('snacks')

      Snacks.setup({
        picker = {
          enabled = true,
          ui_select = true,
          matcher = {
            frecency = true,
            cwd_bonus = true,
            history_bonus = true,
          },
          layout = { preset = 'ivy' },
          win = {
            input = {
              keys = {
                ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
                ['<C-h>'] = { 'toggle_help_input', mode = { 'n', 'i' } },
                ['<a-o>'] = { 'cycle_win', mode = { 'i', 'n' } },
              },
            },
            list = {
              keys = {
                ['<a-o>'] = { 'cycle_win', mode = { 'i', 'n' } },
              },
            },
            preview = {
              keys = {
                ['<Esc>'] = 'cancel',
                ['q'] = 'cancel',
                ['i'] = 'focus_input',
                ['<a-o>'] = { 'cycle_win', mode = { 'i', 'n' } },
              },
            },
          },
        },
      })

      local picker = Snacks.picker
      local session = require('my.plugin.session')
      local map = vim.keymap.set

      -- Open the picker listing saved sessions, loading the selected one
      local function find_sessions()
        picker.files({
          title = 'Find sessions (workspaces)',
          cwd = session.opts.dir,
          constrain_cursor = false,
          preview = 'main',
          matcher = { frecency = true },
          confirm = function(p, item)
            p:close()
            session.load(item.file)
          end,
        })
      end

      -- stylua: ignore start
      map('n', '<Leader>.', function() picker.files() end, { desc = 'Find files' })
      map('n', "<Leader>'", function() picker.resume() end, { desc = 'Resume last picker' })
      map('n', '<Leader>`', function() picker.marks() end, { desc = 'Find marks' })
      map('n', '<Leader>,', function() picker.buffers() end, { desc = 'Find buffers' })
      map('n', '<Leader>/', function() picker.grep() end, { desc = 'Grep' })
      map('n', '<Leader>?', function() picker.help() end, { desc = 'Find help files' })
      map({ 'n', 'x' }, '<Leader>*', function() picker.grep_word() end, { desc = 'Grep word under cursor' })
      map({ 'n', 'x' }, '<Leader>#', function() picker.grep_word() end, { desc = 'Grep word under cursor' })
      map('n', '<Leader>"', function() picker.registers() end, { desc = 'Find registers' })
      map('n', '<Leader>:', function() picker.commands() end, { desc = 'Find commands' })
      map('n', '<Leader>F', function() picker.pickers() end, { desc = 'Find all available pickers' })
      map('n', '<Leader>o', function() picker.recent() end, { desc = 'Find oldfiles' })
      map('n', '<Leader>-', function() picker.lines() end, { desc = 'Find lines in buffer' })
      map('x', '<Leader>-', function() picker.lines() end, { desc = 'Find lines in selection' })
      map('n', '<Leader>=', function() picker.grep_buffers() end, { desc = 'Find lines across buffers' })
      map('n', '<Leader>n', function() picker.treesitter() end, { desc = 'Find treesitter nodes' })
      map('n', '<Leader>R', function() picker.lsp_references() end, { desc = 'Find symbol locations' })
      map({ 'n', 'x' }, '<Leader>f*', function() picker.grep_word() end, { desc = 'Grep word under cursor' })
      map({ 'n', 'x' }, '<Leader>f#', function() picker.grep_word() end, { desc = 'Grep word under cursor' })
      map('n', '<Leader>f:', function() picker.commands() end, { desc = 'Find commands' })
      map('n', '<Leader>f/', function() picker.grep() end, { desc = 'Grep' })
      map('n', '<Leader>fH', function() picker.highlights() end, { desc = 'Find highlights' })
      map('n', "<Leader>f'", function() picker.resume() end, { desc = 'Resume last picker' })
      map('n', '<Leader>fA', function() picker.autocmds() end, { desc = 'Find autocmds' })
      map('n', '<Leader>fb', function() picker.buffers() end, { desc = 'Find buffers' })
      map('n', '<Leader>fd', function() picker.diagnostics_buffer() end, { desc = 'Find document diagnostics' })
      map('n', '<Leader>fD', function() picker.diagnostics() end, { desc = 'Find workspace diagnostics' })
      map('n', '<Leader>ff', function() picker.files() end, { desc = 'Find files' })
      map('n', '<Leader>fl', function() picker.loclist() end, { desc = 'Find location list' })
      map('n', '<Leader>fq', function() picker.qflist() end, { desc = 'Find quickfix list' })
      map('n', '<Leader>ft', function() picker.tags() end, { desc = 'Find tags' })
      map('n', '<Leader>fgs', function() picker.git_stash() end, { desc = 'Find git stash' })
      map('n', '<Leader>fgg', function() picker.git_status() end, { desc = 'Find git status' })
      map('n', '<Leader>fgL', function() picker.git_log() end, { desc = 'Find git logs' })
      map('n', '<Leader>fgl', function() picker.git_log_file() end, { desc = 'Find git buffer logs' })
      map('n', '<Leader>fgb', function() picker.git_branches() end, { desc = 'Find git branches' })
      map('n', '<Leader>fgf', function() picker.git_files() end, { desc = 'Find git files' })
      map('n', '<Leader>fgF', function() picker.git_log({ current_file = true }) end, { desc = 'Find git commits containing file' })
      map('n', '<Leader>fh', function() picker.help() end, { desc = 'Find help files' })
      map('n', '<Leader>fk', function() picker.keymaps() end, { desc = 'Find keymaps' })
      map('n', '<Leader>fm', function() picker.marks() end, { desc = 'Find marks' })
      map('n', '<Leader>fo', function() picker.recent() end, { desc = 'Find oldfiles' })
      map('n', '<Leader>fz', function() picker.zoxide() end, { desc = 'Find directories from z' })
      map('n', '<Leader>fw', find_sessions, { desc = 'Find sessions (workspaces)' })
      map('n', '<Leader>fn', function() picker.treesitter() end, { desc = 'Find treesitter nodes' })
      map('n', '<Leader>fs', function() picker.lsp_symbols() end, { desc = 'Find lsp symbols or treesitter nodes' })
      map('n', '<Leader>fSd', function() picker.lsp_definitions() end, { desc = 'Find symbol definitions' })
      map('n', '<Leader>fSD', function() picker.lsp_declarations() end, { desc = 'Find symbol declarations' })
      map('n', '<Leader>fS<C-d>', function() picker.lsp_type_definitions() end, { desc = 'Find symbol type definitions' })
      map('n', '<Leader>fSs', function() picker.lsp_symbols() end, { desc = 'Find symbol in current document' })
      map('n', '<Leader>fSS', function() picker.lsp_workspace_symbols() end, { desc = 'Find symbol in whole workspace' })
      map('n', '<Leader>fSi', function() picker.lsp_implementations() end, { desc = 'Find symbol implementations' })
      map('n', '<Leader>fS<', function() picker.lsp_incoming_calls() end, { desc = 'Find symbol incoming calls' })
      map('n', '<Leader>fS>', function() picker.lsp_outgoing_calls() end, { desc = 'Find symbol outgoing calls' })
      map('n', '<Leader>fSr', function() picker.lsp_references() end, { desc = 'Find symbol references' })
      -- stylua: ignore end
    end,
  },
}
