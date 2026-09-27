---@type my.lsp.config
return {
  filetypes = { 'python' },
  cmd = { 'ruff', 'server' },
  buf_support = false,
  on_init = function(client)
    client.server_capabilities.hoverProvider = false
  end,
  root_markers = {
    { 'ruff.toml', '.ruff.toml' },
    { 'pyproject.toml' },
    {
      'Pipfile',
      'requirements.txt',
      'setup.cfg',
      'setup.py',
      'tox.ini',
    },
    { 'venv', 'env', '.venv', '.env' },
    { '.python-version' },
  },
}
