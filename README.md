<p align="center"><img src="docs/assets/avra-logo.svg" alt="Avra.nvim — breeze mark" width="340"></p>

# Avra.nvim

**Avra.nvim is a modified fork of [Bekaboo’s Neovim configuration](https://github.com/Bekaboo/dot/tree/master/.config/nvim).** It retains Bekaboo’s [GNU GPL v3 license](LICENSE); the screenshots below are from the original project. Avra (αύρα) means “breeze” in Greek.

A personal Neovim setup with a restrained interface, [Snacks](https://github.com/folke/snacks.nvim) search, [namu.nvim](https://github.com/bassamsdata/namu.nvim) symbol and diagnostic pickers, Tree-sitter, LSP, and [Molten](https://github.com/benlubas/molten-nvim) notebook support. The first launch downloads plugins, baseline parsers, language tools, and an isolated Python provider. Lua uses LuaLS; Python uses Pyrefly for IDE features, ty for type diagnostics, and Ruff for linting and formatting.

<p align="center"><img src="https://github.com/Bekaboo/nvim/assets/76579810/299137e7-9438-489b-b98b-7211a62678ae" width="46%" alt="Original configuration screenshot 1">&nbsp;<img src="https://github.com/Bekaboo/nvim/assets/76579810/9e546e33-7678-47e2-8a80-368d7c59534a" width="46%" alt="Original configuration screenshot 2"></p>

## Prerequisites

Install **Neovim 0.13+**, Git, curl, tar/gzip, unzip, a C compiler and make, Node.js/npm, Rust/Cargo, Tree-sitter CLI **0.26.1+**, Python 3.10+ with pip/venv, [uv](https://docs.astral.sh/uv/), [ripgrep](https://github.com/BurntSushi/ripgrep), and [fd](https://github.com/sharkdp/fd). The first run needs internet access. A Nerd Font is optional. Tested on macOS with the version in [nvim-version.txt](nvim-version.txt); other platforms and optional integrations have not been fully verified.

## Install

Run this in a shell; the destination must not already exist:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}" && git clone https://github.com/bassamsdata/avra.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}/nvim.avra" && NVIM_APPNAME=nvim.avra nvim
```

Keep Neovim open while background parser and Mason installs finish. Later, launch with `NVIM_APPNAME=nvim.avra nvim`. If setup reports a download failure, restart and check `:messages`, `:Mason`, or `:checkhealth`.

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
