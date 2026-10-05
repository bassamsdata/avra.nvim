---Use the same development checkouts as the default Neovim configuration.
---@param spec my.pack.structured_spec
---@param fallback string
local function load_dev(spec, fallback)
  local name = vim.fs.basename(spec.src)
  local path = vim.fn.expand('~/repos/' .. name)
  if not vim.uv.fs_stat(path .. '/lua') then
    path = fallback
  end
  vim.opt.runtimepath:prepend(path)
  for _, file in ipairs(vim.fn.glob(path .. '/plugin/*.lua', false, true)) do
    vim.cmd.source(file)
  end
  if spec.data and spec.data.postload then
    spec.data.postload(spec, path)
  end
end

---@type my.pack.spec
return {
  src = 'https://github.com/olimorris/codecompanion.nvim',
  data = {
    deps = {
      'https://github.com/nvim-lua/plenary.nvim',
      'https://github.com/nvim-treesitter/nvim-treesitter',
      {
        src = 'https://github.com/bassamsdata/hive.nvim',
        data = { load = load_dev },
      },
    },
    cmds = {
      'CodeCompanion',
      'CodeCompanionChat',
      'CodeCompanionActions',
      'CodeCompanionCmd',
      'Hive',
    },
    keys = {
      { lhs = '<Leader>Ac', opts = { desc = 'AI chat' } },
      {
        lhs = '<Leader>Aa',
        mode = { 'n', 'x' },
        opts = { desc = 'AI actions' },
      },
    },
    load = load_dev,
    postload = function()
      require('codecompanion').setup({
        adapters = {
          http = {
            zai = function()
              return require('my.pack.res.codecompanion.zai').adapter()
            end,
          },
        },
        interactions = {
          chat = { adapter = 'zai' },
          inline = { adapter = 'zai' },
          cmd = { adapter = 'zai' },
          background = { adapter = 'zai' },
        },
        extensions = { hive = { enabled = true, opts = {} } },
      })
      vim.keymap.set('n', '<Leader>Ac', '<Cmd>CodeCompanionChat toggle<CR>', {
        desc = 'AI chat',
      })
      vim.keymap.set({ 'n', 'x' }, '<Leader>Aa', function()
        require('codecompanion').actions()
      end, { desc = 'AI actions' })
    end,
  },
}
