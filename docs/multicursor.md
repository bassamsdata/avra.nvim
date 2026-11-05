# Native multicursors (Neovim nightly 0.13)

These shortcuts use the builtin engine; no multicursor plugin is required.
`<Leader>` is Space. The new shortcuts load on `UIEnter`, like the other
core mappings.

| Keys | Modes | Action |
| --- | --- | --- |
| `[count] Space mj` | Normal | Keep a cursor here and move down, repeated count times |
| `[count] Space mk` | Normal | Keep a cursor here and move up, repeated count times |
| `[count] Space mn` | Normal, Visual | Add the next count matches of this word or literal selection |
| `Space mc` | Normal, Visual | Clear extra cursors and return to Normal mode |
| `Ctrl-l` | Normal, Visual, outside Herdr | Clear cursors, search highlighting, and redraw |
| `Q` | Normal | Toggle a cursor here (`1Q` always adds, `2Q` removes) |
| `Q` | Visual | Place cursors on the selected lines; enables follow mode |
| `Ctrl-left-click` | Normal, Visual | Toggle a cursor at the mouse, keeping the primary cursor in place |
| `Esc` | Insert, Visual | Leave the mode; retain extra cursors |

To change the current word and its **next four matches**, place the cursor
on it and type `4 Space mn`, then `cgnreplacement<Esc>`. This edits five
locations: the original plus four more. Finish with `Space mc`.
For a phrase, visually select it first, then use `4 Space mn` and the same
`cgn` edit. Matches follow the search settings, including `wrapscan`.
The match shortcut sets the `/` search register, like `*`.

`Ctrl-c` interrupts a running multicursor replay; it does not end the
session. In idle Normal mode the standard quit hint is expected. Molten
also maps `Ctrl-c` to interrupt the kernel in Python/notebook buffers, and
Oil uses it to close its buffer. `Space mc` avoids those conflicts.

The custom `Ctrl-l` redraw mapping previously omitted nightly's namespace
clear. It now clears cursors even when search highlighting is active.
Herdr intentionally uses `Ctrl-l` for pane navigation, so use `Space mc`
there. The existing Normal-mode `Esc` mapping still closes floating
windows.

Mouse support requires Neovim's `mouse` option (default `nvi`) and a
terminal that forwards Ctrl-click. Ctrl-click is a no-op in Insert mode.
On macOS a terminal may reserve Ctrl-click for its context menu; use `Q`
if it is intercepted. Modified arrows can also be intercepted by macOS
Mission Control, terminals, or notebook mappings; the Space shortcuts
avoid them. The Kitty multiple-cursors protocol only improves rendering:
other terminals display the extra cursors with the `MCursor` highlight.

See `:help multicursor`, `:help Q`, and `:help mcursor-mouse` in your
installed nightly. This was verified on `v0.13.0-dev-2008+g9213ffc7da`.
On this build, `4Q` does not add four matches; counted `Q` only accepts
`1` (add) and `2` (remove).
