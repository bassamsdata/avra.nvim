# Codex providers

Use Codex with your normal OpenAI account, the Z.ai GLM Coding Plan, or
OpenRouter. Normal Codex uses `~/.codex`, GLM uses `~/.codex-glm`, and
OpenRouter uses `~/.codex-openrouter`.
Their saved sessions, history, memories, logs, and SQLite state are separate.

## Neovim

| Shortcut | Command | Action |
| --- | --- | --- |
| `Space Ao` | `:AI` | Choose Codex, GLM, or OpenRouter |
| `Space Ax` | `:AI codex` | Open normal Codex |
| `Space Ag` | `:AI glm` | Open Codex using GLM |
| `Space Ar` | `:AI openrouter` | Open Codex using OpenRouter |

Each launch opens a new terminal session in a vertical split at the current
file's project root, falling back to Neovim's working directory. The picker
captures the project before opening, so changing buffers while it is open
does not change the launch directory. Existing CodeCompanion and Hive
shortcuts remain available.

Leave terminal input with `Ctrl-\ Ctrl-n`; then use normal window commands
or `:hide` to hide the split without ending the session. Find a hidden
session with `Space ,` (buffers). Exit Codex with its normal quit command.

## Terminal

The local launchers in `~/.local/bin` forward all arguments:

```sh
cx                       # Normal Codex in ~/.codex
glm                      # GLM in ~/.codex-glm
glm -C ~/repos/project   # Open a particular project
glm resume               # Resume a session from the GLM home
glm -m glm-5.3-flash      # Start with GLM-5.3-Flash
cxo                      # OpenRouter in ~/.codex-openrouter
cxo -m 'provider/model-id' # Replace with an exact OpenRouter model ID
```

`cx`, `glm`, and `cxo` must be on `PATH`. All launchers explicitly select their
home and SQLite directory, including when launched with an inherited
`CODEX_HOME` or `CODEX_SQLITE_HOME`. GLM and OpenRouter use `--no-daemon` to avoid
connecting to a shared background server. Neovim uses these same launchers.

To launch GLM directly without its wrapper:

```sh
CODEX_HOME="$HOME/.codex-glm" codex --no-daemon --profile glm
```

Plain `codex --profile glm` no longer selects GLM: the old profile under
`~/.codex` was retired to avoid using shared state by accident.

Use `/model` inside `glm` to choose `glm-5.3` or `glm-5.3-flash`.
GLM-5.3 remains the default. Inside `cxo`, `/model` lists OpenRouter models;
use the exact provider-prefixed slug when launching with `-m`. Choose a
model with tool support for coding work. OpenRouter defaults to
`openai/gpt-6.1-sol`, matching normal Codex's model family. OpenRouter
usage is billed separately from the OpenAI and Z.ai subscriptions.

## Local profile and credentials

The machine-local files are:

- `~/.codex-glm/config.toml`: private state paths and credential stores.
- `~/.codex-glm/glm.config.toml`: GLM provider, model, catalog, and key helper.
- `~/.codex-glm/glm-models.json`: GLM model metadata for Codex.
- `~/.codex-openrouter/config.toml`: OpenRouter provider and private state.
- `~/.local/bin/cx`, `~/.local/bin/glm`, and `~/.local/bin/cxo`: launchers.

The profile selects `glm-5.3` with `high` reasoning and uses Z.ai's Responses
endpoint, `https://api.z.ai/api/v1`. It obtains the bearer token with
`api-pass show zai --key` when needed. This may request biometric unlock;
no API key is written into the profile or this repository. The stored `zai`
credential must be a Coding Plan key. Standard model API keys are separate.

GLM-5.3-Flash is included in the GLM catalog with its 1M-token context
window and text/image input metadata. Select it with `/model` or
`glm -m glm-5.3-flash` without changing the default model.

OpenRouter uses `https://openrouter.ai/api/v1` and obtains its key from
`api-pass show openrouter --key`. Command-backed authentication lets Codex
refresh OpenRouter's model catalog, including context and reasoning metadata.
The OpenRouter home has no fixed local catalog that would override discovery.

Each new home starts fresh. Existing OpenAI conversations, memories, global
instructions, and home-specific skills/plugins/MCP configuration were not
copied. Memory storage is separate; memory generation is not automatically
enabled by this setup. Both agents can still read the project you open,
its `AGENTS.md`, and skills installed in other global discovery locations.
This separates Codex state; it is not a filesystem access restriction.

To switch the model later, update the GLM profile and its catalog together.

The default `~/.codex/config.toml` and OpenAI login are unchanged. New CLI
and MCP login credentials in the provider homes use file storage there.
Provider keys continue to come from the existing `api-pass` entries. The
desktop app
continues to use its existing configuration; these launchers select GLM
for CLI sessions. Restart old GLM sessions to use the isolated home.

References: [Z.ai Codex integration](https://docs.z.ai/devpack/tool/codex),
[OpenRouter Codex integration](https://openrouter.ai/docs/cookbook/coding-agents/codex-cli),
[Codex profiles and command-backed authentication](https://learn.chatgpt.com/docs/config-file/config-advanced).
