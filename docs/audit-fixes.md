# Audit fixes — October 5, 2026

Removed the requested plugin specs and their lock entries: Cellular Automaton,
DAP/UI/OSV, Metals, VimTeX, vim-test/Dispatch, vim-conjoin, vim-table-mode, and
Everforest. DAP/test-only resources were also removed. Existing cached plugin
checkouts are not loaded by these removed specs. Other plugins were preserved.

## Keys

- `Space ff`: Snacks smart files (already selected before this cleanup).
- `Space .`: plain files.
- `Space ss/sw`: Namu document/workspace symbols.
- `Space si/sI`: Namu document/workspace diagnostics.
- `Space th`: Namu colorschemes, now retained after lazy loading.
- `Space dd`: diagnostic details; replaces the ambiguous `Space d` action.
- `Space fK`: buffer-local which-key view.
- `Space Ac`: toggle CodeCompanion chat.
- `Space Aa`: CodeCompanion actions, in normal or visual mode.

Snacks symbol/navigation mappings and the short `Space n` / `Space s` actions
were removed. Native LSP navigation remains. Which-key groups were updated,
its delay is 300 ms, and obsolete plugin groups were removed. Alt-Shift-R now
rotates windows in the opposite direction to Alt-R. Spelling and comment
textobject descriptions now match their actions. Otter's lazy trigger now
matches its existing Markdown/Norg/Org activation list.

## Formatting

`gq;` calls native LSP formatting. `:LspAutoFormat` enables the existing
opt-in automatic formatting behavior. No Conform or new formatter was added.

| Language | Configured formatter path |
| --- | --- |
| Lua | StyLua through efm-langserver; LuaLS formatting is disabled |
| Python | Ruff; the Python allowlist excludes the Black/isort adapters |
| R | R `languageserver` formatting; no Air integration |
| Rust | rust-analyzer formatting, normally using rustfmt |

Tools must be available and their clients attached for formatting to work.
This cleanup did not validate R/Rust tool installations or run formatters.

## CodeCompanion and Hive

Both use the same `~/repos/` development checkouts as the default config when
available, with managed checkouts as fallback. They load on the CodeCompanion
commands, `:Hive`, or the AI shortcuts. The only new plugin specs are
CodeCompanion and Hive; Plenary and Tree-sitter were already dependencies.
Namu's development loader is retained, with the managed checkout as fallback
when `~/repos/namu.nvim` is absent.

Z.ai uses the existing default config's endpoint, model, and reasoning handlers.
Credentials are resolved on demand from the environment, `api-pass`, or a secret
prompt. No credentials are copied into this repository. No API request was sent.

Quicker is active after UI entry and clears Avra's local quickfix syntax when it
handles a quickfix buffer. The local quickfix customizations coexist with it.

Headless checks used isolated temporary state and the existing local plugins:
Namu mappings after lazy loading, CodeCompanion/Hive initialization and delayed
loading, Quicker loading, smart picker dispatch, diagnostic keys, window rotation,
and which-key setup. Full interactive startup and provider authentication remain
unverified.

## Installation verification

The README command uses portable shell syntax on macOS and Linux. Verification
covered syntax in sh/bash/zsh, a real HTTPS clone into an XDG path containing
spaces, the `NVIM_APPNAME` passed to a stub launcher, and refusal to overwrite
an existing destination. A separate headless check loaded the managed Namu,
CodeCompanion, and Hive checkouts with development paths unavailable.

A Linux runtime was not available for a complete fresh bootstrap test. System
prerequisites still need to be installed first; Mason tool installation begins
when a source file opens or `:Mason` runs. The command does not replace the
normal `nvim` configuration or install Neovim itself.
