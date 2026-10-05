<p align="center"><img src="docs/assets/avra-logo.svg" alt="Avra.nvim — breeze mark" width="340"></p>

# Avra.nvim

**Avra.nvim is a modified fork of [Bekaboo’s Neovim configuration](https://github.com/Bekaboo/dot/tree/master/.config/nvim).** It retains Bekaboo’s [GNU GPL v3 license](LICENSE); the screenshots below are from the original project. Avra (αύρα) means “breeze” in Greek.

A personal Neovim setup with a restrained interface, [Snacks](https://github.com/folke/snacks.nvim) search, [namu.nvim](https://github.com/bassamsdata/namu.nvim) symbol and diagnostic pickers, Tree-sitter, LSP, and [Molten](https://github.com/benlubas/molten-nvim) notebook support. The first launch downloads plugins, baseline parsers, language tools, and an isolated Python provider. Lua uses LuaLS; Python uses Pyrefly for IDE features, ty for type diagnostics, and Ruff for linting and formatting.

<p align="center"><img src="https://github.com/Bekaboo/nvim/assets/76579810/299137e7-9438-489b-b98b-7211a62678ae" width="46%" alt="Original configuration screenshot 1">&nbsp;<img src="https://github.com/Bekaboo/nvim/assets/76579810/9e546e33-7678-47e2-8a80-368d7c59534a" width="46%" alt="Original configuration screenshot 2"></p>

## Prerequisites

Install **Neovim 0.13+**, Git, curl, tar/gzip, unzip, a C compiler and make, Node.js/npm, Rust/Cargo, Tree-sitter CLI **0.26.1+**, Python 3.10+ with pip/venv, [uv](https://docs.astral.sh/uv/), [ripgrep](https://github.com/BurntSushi/ripgrep), and [fd](https://github.com/sharkdp/fd). The first run needs internet access. A Nerd Font is optional. Tested on macOS with the version in [nvim-version.txt](nvim-version.txt); other platforms and optional integrations have not been fully verified.

## Install

The same command works in a POSIX-compatible shell on macOS or Linux once
the prerequisites above are installed. It installs Avra alongside your existing
Neovim configuration; the destination must not already exist:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}" && git clone https://github.com/bassamsdata/avra.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}/nvim.avra" && NVIM_APPNAME=nvim.avra nvim
```

Keep Neovim open while background parser installs finish. Open a source file
(or run `:Mason`) to start the lazy baseline language-tool installation. Later, launch with `NVIM_APPNAME=nvim.avra nvim`. If setup reports a download failure, restart and check `:messages`, `:Mason`, or `:checkhealth`.

Namu, CodeCompanion, and Hive prefer your `~/repos/` development checkouts
when present and otherwise use their managed installations. No development
checkout is required on a fresh machine. CodeCompanion and Hive load only when
you use an AI command or shortcut; configure provider credentials separately.

**[Documentation and searchable keymaps](https://bassamsdata.github.io/avra.nvim/)** · [Configuration review](https://bassamsdata.github.io/avra.nvim/config-review.html) · [License](LICENSE)

## Secret masking

Avra automatically conceals each assignment-value character with `*` in
`.env`, `.env.*`, `*.env`, `.npmrc`, `.pypirc`, and `~/.aws/credentials` files. Keys and standalone
comments remain visible; quoted multiline values and continued lines are
masked too. Values stay hidden while typing and selecting text.

Press `<Leader>up` or run `:SecretsToggle` to reveal/hide the current file.
These controls exist only in matching buffers. To add other assignment-based
files, extend `secret_patterns` in `plugin/_load.lua`. This is an assignment
parser, not a general JSON/YAML or arbitrary-secret detector.

No plugin dependency is needed. Startup only registers filename triggers;
the module loads on the first matching file and updates attached buffers only.
Masking changes the display, not the file, clipboard, search results, or other
previews. Window conceal settings are restored when leaving a protected file.

## Appearance and terminal tool themes

Use `:Appearance` for all appearance settings. It shows status without
arguments and completes subcommands with Tab. Press **Space, Shift-T** in
normal mode to toggle transparency.

| Command | Effect |
| --- | --- |
| `:Appearance transparency [on\|off\|toggle]` | Clear Neovim backgrounds; retain text and selection styles |
| `:Appearance ghostty [on\|off\|toggle]` | Enable or disable Ghostty theme sync |
| `:Appearance herdr [on\|off\|toggle]` | Enable or disable Herdr interface sync |
| `:Appearance btop [on\|off\|toggle]` | Enable or disable BTOP theme sync |
| `:Appearance lazygit [on\|off\|toggle]` | Enable or disable Lazygit theme sync |
| `:Appearance yazi [on\|off\|toggle]` | Enable or disable Yazi theme sync |
| `:Appearance opencode [on\|off\|toggle]` | Enable or disable OpenCode TUI theme sync |
| `:Appearance persist ghostty [on\|off\|toggle]` | Keep Ghostty's applied theme after Neovim exits |
| `:Appearance persist herdr [on\|off\|toggle]` | Keep Herdr's applied theme after Neovim exits |
| `:Appearance persist all [on\|off\|toggle]` | Set persistence for both terminals |
| `:Appearance refresh` | Reapply the current theme, force a Ghostty reload, and show status |
| `:Appearance export [path]` | Export a reusable Ghostty theme file |
| `:Appearance status` | Show preferences, integrations, Ghostty config ownership, and reload errors |

Omitting `on`, `off`, or `toggle` toggles the setting. `:Appearance persist`
toggles persistence for both terminals. All preferences are remembered across
Neovim restarts. Sync is enabled by default. Ghostty and Herdr persistence is
off by default, so themes changed by this Neovim session are restored when it
exits. Suspending or detaching the UI leaves the applied theme in place until
exit. Disabling sync restores the theme from before the current session, even
when persistence is enabled. A theme kept by a previous session becomes the
baseline for the next session.

On macOS with Ghostty 1.3 or newer, appearance sync exports the active
colorscheme, adds a managed include to the last native Ghostty config, and
calls Ghostty's AppleScript `reload_config` action. This also works when
Neovim runs inside Herdr. It changes Ghostty's configuration across its tabs
and windows without restarting Ghostty. The first reload may prompt for
macOS Automation permission; allow access to Ghostty, then run
`:Appearance refresh` if needed. This requires local Ghostty environment
variables and an attached terminal UI; it does not run over SSH or in a
headless/graphical Neovim session. See [Ghostty's AppleScript documentation](https://ghostty.org/docs/features/applescript).

`:Appearance refresh` always retries Ghostty's reload, even when the palette
has not changed. Its status shows the config path, the owning Neovim PID,
whether this session installed the theme, and any reload error. Availability
alone means the integration can run; it does not confirm a successful reload.
Ghostty preserves active OSC color overrides when reloading its config. In
Ghostty 1.3.1, even resetting an OSC color leaves a fixed override that blocks
later config color changes. Avra uses config colors alone when global sync is
available directly in Ghostty, including through tmux. Herdr still receives
OSC colors inside its virtual panes. Existing affected Ghostty tabs need to
be recreated once to discard their old overrides; subsequent config theme
changes do not need a restart. See [the upstream fix](https://github.com/ghostty-org/ghostty/pull/13650).

Avra preserves Ghostty's configured opacity and other settings. The managed
theme is `stdpath('state')/ghostty-sync-theme`; the originals and session
ownership are recorded in `stdpath('state')/ghostty-sync.json` before files
are changed. Temporary themes are restored on exit. Persistent themes retain
the include and exported colors. Only one Neovim session controls the shared
Ghostty config at a time. If you edit the config or generated theme while sync
is active, Avra preserves your edits and the recovery journal.

Where global reload is unavailable, terminal RGB color updates match the
current pane's foreground, background, cursor, and 16 ANSI colors without
installing a colorscheme in Ghostty. For this pane sync in tmux, enable
`set -g allow-passthrough on` to receive these updates. With transparency on,
Avra resets the pane's default background so Herdr can reveal the host's
backdrop instead of painting an opaque RGB background.

Inside Herdr, appearance sync also matches tabs, sidebar, borders, and
selections. It validates a temporary config with `herdr config check`, applies
custom theme colors, and calls `herdr server reload-config`. The original
config is backed up as `config.toml.avra-backup` for restoration and crash
recovery. Persistence keeps the applied colors and removes the backup on
normal exit. User edits are preserved. Herdr 0.9.0 and newer support these
theme options.

BTOP, Lazygit, and Yazi also follow the Neovim palette by default. Avra
generates `~/.config/btop/themes/avra-nvim.theme`, sets only BTOP's
`color_theme` option, and sends `SIGUSR2` to running BTOP processes owned by
the current user after a change. BTOP's previous theme is recorded in
`stdpath('state')/btop-sync.json` and restored with `:Appearance btop off`.
Lazygit and Yazi receive marked theme blocks in their existing config files;
disabling sync removes those blocks while preserving the surrounding settings.
These three themes stay in effect after Neovim exits. Lazygit reads changed
config when its terminal regains focus; Yazi reads its theme when it starts,
so restart an open Yazi session to see a new theme.

OpenCode's TUI also follows the current Neovim highlights by default. Avra
generates `$XDG_CONFIG_HOME/opencode/themes/avra-nvim.json` (normally
`~/.config/opencode/themes/avra-nvim.json`) and selects it in `tui.jsonc` or
`tui.json`. Comments, trailing commas, and unrelated settings are preserved.
The selection persists after Neovim exits. `:Appearance opencode off`
restores the previous selection and removes the unedited generated theme.
Recovery information lives in `stdpath('state')/opencode-sync.json`.
Focused menu text is chosen against OpenCode's `primary` background, with
a minimum contrast of 4.5:1. The same token is used for warning/paste badges;
if needed, only the exported warning color is shaded to keep that text
readable too. Avra's Neovim palettes are preserved.
Transparency applies to OpenCode's main canvas. Dialog panels and slash
menus always use solid theme colors, hiding the text beneath them. OpenCode
adds its own dimming layer around dialogs; its black tint is fixed in
OpenCode 1.18.30 and cannot be configured through theme JSON.
Restart an open OpenCode session after changing the theme. Project TUI
settings take precedence over the global selection; remove a project theme
override if you want it to follow Avra. Explicit `OPENCODE_TUI_CONFIG` or
`OPENCODE_CONFIG_DIR` overrides disable this global integration.

Appearance setup is lazy loaded on `UIEnter`. Neovim restores its own saved
background early in `my.core.autocmds` and applies saved transparency after
the initial colorscheme loads. Startup, resume, and UI reattachment do not
check or change other tools' themes, regardless of persistence. The first
colorscheme or background change after startup, a transparency toggle, or
`:Appearance refresh` synchronizes enabled tools. Persistence controls only
whether Ghostty and Herdr keep the applied theme when Neovim exits. Run
`:Appearance refresh` once after first enabling an integration if you have not
changed the theme yet. If Neovim crashes after a temporary sync, its recovery
files are handled on the next explicit sync or refresh.

`:Appearance export` writes `stdpath('state')/ghostty-theme` by default and
reports its full path. An explicit path exports there instead. For manual
setup, add `config-file = /full/path/to/ghostty-theme` after other theme
includes and reload Ghostty with **Cmd+Shift+,** on macOS or **Ctrl+Shift+,**
on Linux. Automatic sync manages its own separate theme file.

## Ayu colorschemes

Ayu is integrated directly, with no theme plugin dependency:

| Command | Variant |
| --- | --- |
| `:colorscheme ayu-dark` | Dark |
| `:colorscheme ayu-mirage` | Mirage |
| `:colorscheme ayu-light` | Light |
| `:colorscheme ayu` | Dark or Light according to `:set background=dark` or `:set background=light` |

Explicit variants set their matching background automatically. Ayu retains
the established palettes used by OpenCode's TUI and Shatur's Neovim port,
with Avra's existing Treesitter, LSP, diagnostics, and plugin highlights.
Upstream syntax colors are kept unchanged, including the softer Light
accents; the generator does not enforce AA contrast on every syntax color.
The main text contrast is checked for all variants.

Regenerate only Ayu with
`python3 tools/gen_themes.py ayu ayu-dark ayu-light ayu-mirage`.
`python3 tools/gen_themes.py --check` validates all generator palettes and
template substitutions without writing files. The fixed palettes are in
`tools/ayu-palettes.json`; attribution and license copies are in
[`colors/licenses/README.md`](colors/licenses/README.md).

## Color accessibility checks

`make` now includes `make accessibility-check`, which loads every local
colorscheme with both requested backgrounds in fresh, isolated Neovim
processes. It checks the resolved highlights and the actual OpenCode exporter,
including opaque and transparent focused menu states. It never writes to
your tool configuration or runs your Neovim init file.

The default check blocks theme-load errors and text contrast below 4.5:1 on
Neovim's Normal/NormalFloat, OpenCode's ordinary reading surfaces, and
OpenCode's focused menu and warning badge backgrounds. It also requires
opaque dialog and menu surfaces, even with transparency on. Regression
tests reproduce both reported menu failures and verify they are detected.

Run `make accessibility-report` to create `/tmp/avra-contrast-report.html`.
Open it in a browser to filter findings by theme or highlight name, see
foreground/background previews, and explore every distinct RGB pair in the
palette matrix. Override the output with
`make accessibility-report CONTRAST_REPORT=/path/to/report.html`.

The report also audits syntax beneath selection/search/cursor-line overlays,
explicit and inherited plugin highlights, exported Markdown/syntax/diff
colors, and UI indicator contrast against a 3:1 target. Broader findings
are measurements for review; palette helper highlights appear only in the
all-color matrix because they have no defined text surface. Other findings
remain visible: some original palettes, particularly Ayu Light, intentionally
use soft colors that fall below the normal text target. They are not silently
recolored or described as fully accessible. Decorative separators can be
exempt from non-text contrast requirements.

For a stricter audit, run `python3 tools/check_contrast.py --strict`; it fails
on every modeled finding. Limit an audit with theme names, for example
`python3 tools/check_contrast.py ayu-dark ayu-mirage ayu-light --report /tmp/ayu.html`.
Add `--json /tmp/contrast.json` to export measurements and all-pair matrices.
Inherited surfaces are documented assumptions. Blended overlays and unknown
transparent terminal backdrops are listed as unmeasured, not passed.

The pipeline uses the opaque sRGB luminance and contrast formula from
[WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
It requires only Python 3 and Neovim; browser tools such as
[axe-core](https://github.com/dequelabs/axe-core) audit web content and do not
read terminal highlight states. These checks cover colors, not keyboard
accessibility, screen reader support, or full WCAG conformance.

Ghostty needs `background-opacity` below 1 for a see-through window. See
[opacity options](https://ghostty.org/docs/config/reference#background-opacity)
and the [terminal color API](https://ghostty.org/docs/vt/osc/1x).
