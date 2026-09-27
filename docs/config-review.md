# Avra configuration review

Reviewed against `NVIM v0.13.0-dev-1649+gc171a697cb` on macOS (2026-09-26).
Avra is the renamed `nvim.fast` configuration. The regular `~/.config/nvim`
configuration and its plugin data were left unchanged.

## What was wrong

- **Namu loading:** the custom lazy-loader accepts command names, but its spec
  registered `Namu symbols`, `Namu workspace`, etc. Neovim rejects command names
  containing spaces. An outer `pcall` hid the error and could interrupt later
  plugin setup. The trigger is now just `Namu`, and loader errors are reported.
  Workspace/diagnostic shortcuts also load the plugin on their first use.
- **Namu preview:** both configurations use namu commit `9b0b526`. The regular
  config's Lazy dev rule selects a local namu checkout; Avra installs the GitHub
  checkout. Neither disables automatic preview. Namu documents Tree-sitter as
  a live-preview requirement: its symbol preview only moves/highlights when
  it finds a syntax node. The old fast app's parser directory was empty.
  No namu source changes were made. Adding a parser-independent fallback would
  be a separate plugin change, to discuss before implementation.
- **Lua parser versus LSP:** Neovim's bundled Lua parser already worked, but
  LuaLS was not on fast's PATH. The regular config had Mason-installed servers;
  fast had only configuration files. Avra now installs its own tools. LuaLS
  recognizes LuaJIT, `vim`, and Neovim runtime definitions. `.luarc.json` no
  longer scans the regular config's entire data directory. Luacheck no longer
  attaches automatically alongside LuaLS.
- **First launch:** plugin downloads existed, but were interactive; parsers were
  only updated, never ensured; servers had to be installed by hand; the Python
  provider pointed at a personal a personal virtual environment. Bootstrap now covers those
  gaps, including remote-plugin registration. Tree-sitter uses the current main
  API and eager loading. Failed installs remain visible and retry on restart.
- **Python:** blanket LSP activation could start every installed Python checker
  and formatter. Avra now enables only Pyrefly, ty, and Ruff for Python.
- **Diagnostics:** `Space d` meant a diagnostic float in the regular config but
  a location list in fast. It now opens details in both. Diagnostic shortcuts
  are available at startup, rather than appearing after the first diagnostic.
- **Other fixes:** the floating-preview wrapper now accepts omitted options;
  list-form build commands are type-checked correctly. Two pre-existing trivial
  formatting issues were corrected so the required repository checks pass.

## Python responsibilities

The Meta project is **Pyrefly**, not Butterfly. Both Pyrefly and ty can provide
complete language-server functionality, so using both is optional, rather than
necessary. This configuration honors the requested pair with explicit roles:

| Tool | Responsibility | Disabled |
| --- | --- | --- |
| Pyrefly | Completion, hover, definitions, references, rename, symbols | Type diagnostics (`disableTypeErrors`) |
| ty | Type diagnostics | IDE services (`disableLanguageServices`) and their advertised client capabilities |
| Ruff | Linting, code actions, import organization, formatting, syntax errors | Hover |

Ty's syntax errors are disabled so Ruff owns syntax errors. Pyright, Pyre,
Jedi, pylsp, mypy, pylint, flake8, Black and isort wrappers are not auto-enabled.
Project settings can still deliberately request overlapping Ruff/type rules;
this is not a global message-deduplication scheme.

Use a project `.venv` or your active environment for application dependencies.
The private Neovim provider is deliberately not prepended as the project Python.
The provider includes a basic `nvim-python` Jupyter kernel; optional language
kernels and notebook graphics dependencies are separate.

References: [Pyrefly settings](https://pyrefly.org/en/docs/IDE/),
[ty settings](https://docs.astral.sh/ty/reference/editor-settings/),
[Mason](https://github.com/mason-org/mason.nvim),
[Tree-sitter](https://github.com/nvim-treesitter/nvim-treesitter).

## Daily cheat sheet

Leader is **Space**. Normal mode unless specified. Lowercase/uppercase differ.
Workspace diagnostics mean diagnostics already known to attached servers;
opening a workspace picker does not itself scan every file in the repository.

| Action | Keys | Comparison with regular config |
| --- | --- | --- |
| Details on this line | `Space d` | Now the same; repeat to focus the float |
| Diagnostic detail alternatives | `Ctrl-w d`, `Space i`, `Alt-d` | Fast's existing alternatives remain |
| Next / previous diagnostic | `]d` / `[d` | Familiar native defaults; count works, e.g. `3]d` |
| Next / previous error only | `]e` / `[e` | Matches regular; count works |
| Next / previous warning | `]w` / `[w` | Fast addition |
| First / last diagnostic | `[D` / `]D` | Native defaults retained |
| Current-file diagnostics picker | `Space si` | Namu; matches regular |
| Workspace diagnostics picker | `Space sI` | Namu; matches regular |
| Alternative diagnostic pickers | `Space fd` / `Space fD` | Snacks: file / workspace |
| File diagnostics location list | `Space dl` | Former fast `Space d` moved here |
| Workspace diagnostics quickfix | `Space D` | Fast's existing list mapping |
| Next / previous location-list entry | `]l` / `[l` | Native defaults |
| Next / previous quickfix entry | `]q` / `[q` | Native defaults |
| Copy line's diagnostic message | `yd` | Chooses one if several exist |
| Symbol hover docs | `K` | LSP hover, distinct from diagnostic details |
| Code actions | `gra` or `Space a` | Native shortcut plus fast alias |
| Rename | `grn` or `Space r` | Native key retained; custom rename helper underneath |
| Definition / jump back | `gd` / `Ctrl-o` | Fast uses native LSP locations; regular wraps this with Glance |
| References / implementation / type | `grr` / `gri` / `grt` | Native defaults; fast also offers `g/`, `g.`, `gb` |
| Signature help (insert mode) | `Ctrl-s` | Native LSP default retained |
| Buffer / workspace symbols | `Space ss` / `Space sw` | Namu, matching regular |
| Move inside Namu | `Ctrl-n`/`Ctrl-p`, `Ctrl-j`/`Ctrl-k`, arrows | Matching movement aliases; previews automatically |
| Choose / close Namu | `Enter` / `Esc` | Picker defaults |
| Find files / buffers / text | `Space ff` / `Space fb` / `Space /` | Familiar common picker keys |
| Next / previous buffer | `]b` / `[b` | Native; regular also uses `L` / `H` |
| Move between windows | `Ctrl-w h/j/k/l` or `Alt-h/j/k/l` | Fast prefers Alt; regular has Ctrl-h/j/k/l aliases |
| Browse mappings | `Space fk` | Snacks keymap picker |
| Format current buffer | `gq;` | LSP formatting; StyLua for Lua, Ruff for Python |

## Actual 0.13 default overrides

Compared live mappings from the installed binary's `--clean` startup against
Avra after FileType/UIEnter and InsertEnter. This matters because 0.13 is still
nightly; documentation for a different nightly can disagree.

| Default | Avra behavior | Assessment |
| --- | --- | --- |
| `[d`, `]d` | Same counted diagnostic jumps, also available in visual mode; configured float on jump | Useful continuity, mostly redundant wrappers |
| `Ctrl-w d`, `Ctrl-w Ctrl-d` | Opens details and focuses an existing diagnostic float on repeat | Useful enhancement |
| `Ctrl-l` | Clears messages/search highlighting, updates diff, redraws | Useful but changes native redraw behavior |
| `-` | Oil directory editor | Useful file-manager replacement for native directory opening |
| Visual `an`, `in` | Prefer LSP selection ranges, fall back to Tree-sitter plugin | Useful fallback; overlaps growing native support |
| Insert `Ctrl-w`, `Ctrl-u` | Custom readline deletion preserving small-delete register | Personal preference; changes native undo-break deletion |
| Insert `Tab`, `Shift-Tab` | Tabout navigation, with completion/snippet behavior through the configured plugins | Useful if preferred, but more complex than native snippet jumps |
| Select-mode `Tab`, `Shift-Tab` | LuaSnip snippet navigation | Appropriate while LuaSnip is the snippet engine |
| Matchit's `%`, `g%`, `[%`, `]%`, `a%` extensions | Matchit disabled; built-in `%` bracket matching remains | Loses richer keyword/HTML matching; personal tradeoff, left unchanged |

`grn`, `gra`, `grr`, `gri`, `grt`, `grx`, `gO`, `Ctrl-s`, `gc`, `gcc`, `[D`,
`]D`, buffer and quickfix/location-list default mappings remain available.
The `grn` function uses fast's existing rename fallback helper, and `gO` lists
symbols in the location list. `K` is installed by Neovim when an attached server
supports hover. **`[e` / `]e` are custom mappings, not defaults in this binary.**

Other traditional Vim changes include wrapped-line `j/k` (counts still move
physical lines), `gf` using `gF` to honor a line number, and LSP-aware `gd/gD`.
These are useful navigation adjustments; they are not new 0.13 defaults.

## Installation and scope

Display name: **Avra**; repository: **avra.nvim**; app/folder:
**nvim.avra**. Launch with `NVIM_APPNAME=nvim.avra nvim`.

See the [installation guide](https://bassamsdata.github.io/avra.nvim/#install) for prerequisites and the clone command.

Automatic baseline: all declared plugins and their build steps, the parser list
in `my.core.parsers`, and the six Mason packages in `my.core.tools`. Optional
servers in `after/lsp` still require installation. Debug adapters, project
runtimes, databases, AI services, TeX, and optional notebook graphics are not
part of the baseline and were not tested.

## Verification

- Final installed Avra tests: LuaLS/StyLua attached for Lua; exactly
  Pyrefly/Ruff/ty attached for Python; no startup errors in either test.
- Repository `make` (StyLua and Luacheck): 0 warnings, 0 errors.
- Empty isolated Neovim data/cache/state: plugin download/build, private Python
  provider and remote-plugin manifest, baseline Mason packages, and parsers.
- Lua and Python Tree-sitter: parsed valid fixtures without syntax errors.
- LuaLS: attached and returned symbols; deliberate undefined global detected.
- Python: Pyrefly returned hover and symbols; ty returned exactly one deliberate
  assignment error; no Pyrefly duplicate. IDE capability ownership checked.
- Namu: real picker's movement callback moved the source cursor and created
  preview extmarks in both Lua and Python. Plugin source unchanged.
- Diagnostic error-only navigation and `Space d` details exercised.
- Sandbox file watchers returned EMFILE; the same tests outside the sandbox
  completed without those errors. npm's sandbox cache failure was also isolated
  to permissions, not a configuration dependency.

These are headless behavior checks, not a full interactive visual review of
every plugin or every language. Fresh Linux/Windows machines, optional servers,
DAP, database/AI integrations, and notebook execution were not tested.
