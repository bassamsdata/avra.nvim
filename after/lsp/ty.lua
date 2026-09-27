-- Python type checker and language server
-- https://github.com/astral-sh/ty

---@type my.lsp.config
return {
  filetypes = { 'python' },
  cmd = { 'ty', 'server' },
  -- ty still advertises IDE methods when services are disabled. Remove
  -- them client-side too, so namu/completion select Pyrefly consistently.
  on_init = function(client)
    for name in pairs(client.server_capabilities) do
      if name:match('Provider$') and name ~= 'diagnosticProvider' then
        client.server_capabilities[name] = false
      end
    end
  end,
  settings = {
    ty = { disableLanguageServices = true, showSyntaxErrors = false },
  },
  root_markers = {
    { 'ty.toml' },
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
