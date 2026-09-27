---@class my.bootstrap
local M = {}

---Create a private Python provider before building remote plugins.
---@return nil
function M.setup()
  if vim.env.NVIM_NO3RD or vim.g.vscode then
    return
  end
  local data = vim.fn.stdpath('data')
  local venv = data .. '/python'
  local python = venv .. '/bin/python'
  local marker = venv .. '/.nvim-provider-v1'
  -- Expose notebook conversion without making the provider Python the
  -- interpreter for unrelated Python projects.
  local bin = data .. '/bin'
  vim.fn.mkdir(bin, 'p')
  if not vim.uv.fs_lstat(bin .. '/jupytext') then
    vim.uv.fs_symlink(venv .. '/bin/jupytext', bin .. '/jupytext')
  end
  vim.env.PATH = bin .. ':' .. vim.env.PATH
  vim.env.JUPYTER_PATH = venv
    .. '/share/jupyter'
    .. (vim.env.JUPYTER_PATH and ':' .. vim.env.JUPYTER_PATH or '')
  if vim.uv.fs_stat(marker) and vim.fn.executable(python) == 1 then
    return
  end
  if vim.fn.executable('uv') == 0 then
    error('Install uv, then restart Neovim to bootstrap its Python provider.')
  end
  vim.fn.mkdir(data, 'p')
  vim.notify('Installing the private Neovim Python provider...')
  local commands = {
    { 'uv', 'venv', '--allow-existing', '--python', '3.12', venv },
    {
      'uv',
      'pip',
      'install',
      '--python',
      python,
      'pynvim',
      'jupyter-client',
      'ipykernel',
      'jupytext',
    },
    {
      python,
      '-m',
      'ipykernel',
      'install',
      '--prefix',
      venv,
      '--name',
      'nvim-python',
      '--display-name',
      'Neovim Python',
    },
  }
  for _, cmd in ipairs(commands) do
    local result = vim.system(cmd, { text = true }):wait()
    if result.code ~= 0 then
      error('Python bootstrap failed (restart to retry): ' .. result.stderr)
    end
  end
  vim.fn.writefile({ 'ready' }, marker)
end

return M
