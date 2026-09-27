---@type my.lsp.config
return {
  filetypes = { 'r', 'rmd', 'quarto' },
  cmd = { 'R', '--slave', '-e', 'languageserver::run()' },
  buf_support = false,
  root_markers = {
    { 'DESCRIPTION' },
    { '.git' },
    { '*.Rproj' },
  },
  settings = {
    r = {
      lsp = {
        rich_documentation = true,
      },
    },
  },
}
