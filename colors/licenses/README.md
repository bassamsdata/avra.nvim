# Ayu attribution

Ayu was created by dempfi (https://github.com/dempfi). The standalone Avra
themes adapt the established Ayu Dark, Mirage, and Light palettes from
[Shatur/neovim-ayu](https://github.com/Shatur/neovim-ayu), revision
`e5a9f0fa2918d6b5f57c21b3ac014314ee5e41c8`, specifically `lua/ayu/colors.lua`.
The palette snapshot is `tools/ayu-palettes.json`. The generated files add
Avra's highlight coverage and semantic mappings; no upstream plugin is
installed. The Neovim port is licensed under GPL-3.0, with its full license
preserved in `neovim-ayu-COPYING`.

The highlight template is Avra's `colors/cockatoo.lua`, by Bekaboo
<kankefengjing@gmail.com>, licensed under GPL-3.0. Generated themes retain
this credit and the repository's GPL license.

Reference implementations reviewed:

- [OpenCode's TUI Ayu](https://github.com/anomalyco/opencode/blob/aa481b8f5652f5576c55f914a64ed270e7daa7e0/packages/tui/src/theme/assets/ayu.json)
  uses the same established Dark syntax colors and background. Its comment
  foreground and some UI/diff surfaces differ; Avra follows the Neovim port
  for those editor roles. No OpenCode implementation code is copied.
- [ayu-theme/ayu-vim](https://github.com/ayu-theme/ayu-vim), revision
  `01faacb4cb76e8cf72ad9858c581d80876260ab3`, provides the original three
  variants under Apache-2.0 (`ayu-vim-LICENSE`). Its older palette differs
  from the Neovim/OpenCode palette selected here. No Vimscript is copied.
- [ayu-theme/ayu-colors](https://github.com/ayu-theme/ayu-colors), revision
  `b0fd979a1ddf050101b43311fa598a1a9c5f1bbc`, now generates revised palettes
  from YAML using OKLCH. Those newer colors differ from OpenCode's TUI;
  they were reviewed but are not used here. Its MIT notice, copyright
  Konstantin Pschera <me@kons.ch>, is preserved in `ayu-colors-LICENSE`.
