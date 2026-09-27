---@type my.pack.spec
return {
  src = 'https://github.com/dstein64/vim-startuptime',
  data = {
    cmds = { 'StartupTime' },
    postload = function()
      vim.g.startuptime_tries = 10
    end,
  },
}
