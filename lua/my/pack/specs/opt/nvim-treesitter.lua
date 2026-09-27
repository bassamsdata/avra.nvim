---@type my.pack.spec
return {
  src = 'https://github.com/nvim-treesitter/nvim-treesitter',
  version = 'main',
  data = {
    -- The main branch requires eager loading. Parser builds remain async.
    build = function()
      vim.cmd.packadd('nvim-treesitter')
      require('nvim-treesitter').update()
    end,
    postload = function()
      require('my.core.parsers').setup()
    end,
  },
}
