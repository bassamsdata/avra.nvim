return {
  filetypes = { 'python' },
  cmd = { 'pyrefly', 'lsp' },
  init_options = { pyrefly = { disableTypeErrors = true } },
  settings = { python = { pyrefly = { disableTypeErrors = true } } },
  root_markers = {
    { 'pyrefly.toml' },
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
