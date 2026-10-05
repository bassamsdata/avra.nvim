#!/usr/bin/env python3
"""Generate standalone colorschemes in colors/ from the cockatoo template.

Usage:
  python3 tools/gen_themes.py                # generate all themes
  python3 tools/gen_themes.py duskveil       # generate only the named theme(s)
  python3 tools/gen_themes.py --check        # validate palettes/template, no write

Adding a new theme
------------------
Add one entry to THEMES below, then run this script. Everything else is
derived:

  name = dict(
      desc='One-line description, derived from cockatoo',
      neutral=285,                 # hue for backgrounds / tinted neutrals
      hues=dict(y=42, o=22, r=352, g=132, t=172, b=224, v=272, m=312),
      #   family hues: y  yellow   o  orange  r  red     g  green
      #               t  teal     b  blue    v  violet  m  magenta
      sat=dict(default=0.92),      # saturation multiplier, per family or all
  )

The script copies the highlight-group body from colors/cockatoo.lua (richest
coverage), swaps the 38-slot palette for the theme, applies the three
Diagnostic-line error-color substitutions described in render(), computes
xterm-256 fallbacks, and nudges lightness minimally until every WCAG pair
passes (see constraints()). Output is stylua- and luacheck-clean.

Ayu uses tools/ayu-palettes.json instead of the hue model. Its upstream
colors are never tuned; Normal contrast, slot coverage, and rendering are
validated. Ayu semantic overrides preserve all template highlight groups.
ayu follows background, while ayu-dark, ayu-light, and ayu-mirage pin it.
Output is deterministic, and all selected themes are validated before writes.

Design model:
- each slot has a role (S/L profile) shared across themes (consistency)
- each theme supplies per-family hue vectors + saturation character
- a constraint-driven tuner nudges lightness minimally until WCAG pairs pass
"""
import argparse
import colorsys
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TEMPLATE_PATH = REPO / 'colors' / 'cockatoo.lua'

# ---------------------------------------------------------------- color utils


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, l / 100.0, s / 100.0)
    return (round(r * 255), round(g * 255), round(b * 255))


def hexof(rgb):
    return '#%02x%02x%02x' % rgb


XT = []
for r in (0, 95, 135, 175, 215, 255):
    for g in (0, 95, 135, 175, 215, 255):
        for b in (0, 95, 135, 175, 215, 255):
            XT.append((r, g, b))
GRAYS = [(8 + 10 * i,) * 3 for i in range(24)]
XT_ALL = XT + GRAYS


def nearest_cterm(rgb):
    def dist(c):
        return 2 * (rgb[0] - c[0]) ** 2 + 4 * (rgb[1] - c[1]) ** 2 + 3 * (rgb[2] - c[2]) ** 2

    best = min(range(len(XT_ALL)), key=lambda i: dist(XT_ALL[i]))
    return 16 + best if best < len(XT) else 232 + (best - len(XT))


def lum(rgb):
    def chan(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (chan(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# ---------------------------------------------------------------- role profiles
# slot -> (family, dark S, dark L, light S, light L)
# families: y=yellow o=orange r=red g=green t=teal b=blue v=violet m=magenta n=neutral
ROLE = {
    'c_yellow':    ('y', 85, 70, 85, 28),
    'c_earth':     ('y', 50, 60, 60, 29),
    'c_orange':    ('o', 94, 66, 90, 38),
    'c_ochre':     ('o', 72, 62, 72, 39),
    'c_pink':      ('r', 50, 76, 52, 46),
    'c_scarlet':   ('r', 95, 67, 90, 41),
    'c_wine':      ('r', 88, 60, 85, 39),
    'c_tea':       ('g', 55, 62, 65, 29),
    'c_aqua':      ('t', 55, 62, 62, 29),
    'c_turquoise': ('t', 62, 60, 68, 38),
    'c_flashlight':('b', 85, 82, 78, 41),
    'c_skyblue':   ('b', 85, 72, 82, 43),
    'c_cerulean':  ('b', 78, 71, 80, 43),
    'c_lavender':  ('v', 78, 74, 78, 42),
    'c_purple':    ('v', 68, 66, 75, 45),
    'c_magenta':   ('m', 72, 70, 78, 43),
    # tinted neutrals
    'c_smoke':          ('n', 12, 91, 22, 14),
    'c_beige':          ('n', 18, 74, 28, 34),
    'c_pigeon':         ('n', 22, 65, 32, 37),
    'c_steel':          ('n', 22, 56, 24, 46),
    'c_cumulonimbus':   ('n', 24, 41, 28, 53),
    'c_thunder':        ('n', 22, 32, 34, 80),
    'c_deepsea':        ('n', 18, 23, 36, 86),
    'c_ocean':          ('n', 18, 19, 36, 91),
    'c_jeans':          ('n', 18, 15, 38, 95),
    'c_iron':           ('n', 18, 17, 28, 81),
    'c_space':          ('n', 18, 7, 24, 99),
    'c_black':          ('n', 12, 4, 12, 97),
    'c_shadow':         ('n', 25, 5, 28, 22),
    # blends (background tints)
    'c_tea_blend':      ('g', 32, 21, 55, 88),
    'c_aqua_blend':     ('t', 32, 21, 55, 88),
    'c_purple_blend':   ('v', 32, 21, 45, 88),
    'c_lavender_blend': ('v', 38, 24, 50, 88),
    'c_scarlet_blend':  ('r', 38, 21, 55, 88),
    'c_wine_blend':     ('r', 32, 20, 45, 88),
    'c_yellow_blend':   ('y', 38, 23, 58, 89),
    'c_smoke_blend':    ('n', 22, 22, 24, 88),
}

SLOTS = list(ROLE)

THEMES = {
    'duskveil': dict(
        desc='Twilight-plum colorscheme with dark and light variants, '
             'derived from cockatoo',
        neutral=285,
        hues=dict(y=42, o=22, r=352, g=132, t=172, b=224, v=272, m=312),
        sat=dict(default=0.92),
    ),
    'pinewood': dict(
        desc='Evergreen-forest colorscheme with dark and light variants, '
             'derived from cockatoo',
        neutral=155,
        hues=dict(y=48, o=30, r=10, g=128, t=168, b=208, v=258, m=322),
        sat=dict(y=0.88, o=0.9, r=0.9, g=1.0, t=0.95, b=0.88, v=0.85, m=0.9),
    ),
    'emberglow': dict(
        desc='Hearthside-amber colorscheme with dark and light variants, '
             'derived from cockatoo',
        neutral=28,
        hues=dict(y=40, o=26, r=356, g=92, t=176, b=212, v=268, m=318),
        sat=dict(y=1.05, o=1.08, r=1.05, g=0.85, t=0.72, b=0.72, v=0.75, m=0.9),
    ),
    'seaglass': dict(
        desc='Oceanic-teal colorscheme with dark and light variants, '
             'derived from cockatoo',
        neutral=198,
        hues=dict(y=46, o=22, r=354, g=150, t=182, b=204, v=252, m=312),
        sat=dict(y=0.85, o=0.8, r=0.82, g=1.0, t=1.05, b=1.02, v=0.9, m=0.85),
    ),
    'roseash': dict(
        desc='Rose-tinted-ash colorscheme with dark and light variants, '
             'derived from cockatoo',
        neutral=338,
        hues=dict(y=44, o=20, r=348, g=138, t=176, b=218, v=288, m=316),
        sat=dict(default=0.95),
    ),
}

# per-family hue offsets for two-slot families (keeps roles distinct)
HUE_OFF = {
    'c_earth': +8, 'c_ochre': -11, 'c_pink': +13, 'c_wine': -7,
    'c_turquoise': +28, 'c_flashlight': -8, 'c_cerulean': +10,
    'c_lavender': +2, 'c_purple': -6,
}

# Keep the established Ayu palettes used by OpenCode's TUI and neovim-ayu.
# These are fixed upstream colors, not hue-generated or contrast-tuned colors.
# Sources and licenses: colors/licenses/README.md.
AYU_PALETTES = json.loads((REPO / 'tools' / 'ayu-palettes.json').read_text())
AYU_THEMES = {
    'ayu': {'dark': 'dark', 'light': 'light'},
    'ayu-dark': {'dark': 'dark', 'light': 'dark'},
    'ayu-light': {'dark': 'light', 'light': 'light'},
    'ayu-mirage': {'dark': 'mirage', 'light': 'mirage'},
}
for name in AYU_THEMES:
    THEMES[name] = dict(desc='Ayu colorscheme, adapted to Avra highlight groups')

AYU_SLOTS = {
    'c_yellow': 'func', 'c_earth': 'special', 'c_orange': 'keyword',
    'c_ochre': 'constant', 'c_pink': 'markup', 'c_scarlet': 'error',
    'c_wine': 'vcs_removed', 'c_tea': 'vcs_added', 'c_aqua': 'regexp',
    'c_turquoise': 'string', 'c_flashlight': 'tag', 'c_skyblue': 'entity',
    'c_cerulean': 'entity', 'c_lavender': 'entity', 'c_purple': 'constant',
    'c_magenta': 'constant', 'c_smoke': 'fg', 'c_beige': 'special',
    'c_pigeon': 'entity', 'c_steel': 'comment',
    'c_cumulonimbus': 'gutter_active', 'c_thunder': 'selection_bg',
    'c_deepsea': 'selection_inactive', 'c_ocean': 'panel_bg',
    'c_jeans': 'bg', 'c_iron': 'guide_normal', 'c_space': 'bg',
    'c_black': 'bg', 'c_shadow': 'panel_shadow',
    'c_tea_blend': 'vcs_added_bg', 'c_aqua_blend': 'vcs_added_bg',
    'c_purple_blend': 'selection_inactive',
    'c_lavender_blend': 'selection_bg',
    'c_scarlet_blend': 'vcs_removed_bg', 'c_wine_blend': 'vcs_removed_bg',
    'c_yellow_blend': 'selection_inactive', 'c_smoke_blend': 'panel_bg',
}


def fixed_color(value):
    if not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
        raise ValueError(f'invalid palette color: {value}')
    rgb = tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
    return dict(hex=value.lower(), cterm=nearest_cterm(rgb), rgb=rgb)


def build_ayu(variant):
    if set(AYU_SLOTS) != set(SLOTS):
        raise ValueError('Ayu palette slots do not match the template')
    return {slot: fixed_color(AYU_PALETTES[variant][role])
            for slot, role in AYU_SLOTS.items()}


def render_ayu(name, src):
    # Preserve every template group but use Ayu's semantic colors for syntax
    # and UI roles that cannot share a single cockatoo palette slot.
    roles = {
        'String': ('string',), 'Character': ('string',),
        'Comment': ('comment',),
        'Statement': ('keyword',), 'Specifier': ('keyword',),
        'Keyword': ('keyword',), 'Exception': ('keyword',),
        'Operator': ('operator',), 'Special': ('special',),
        'PreProc': ('special',), 'Builtin': ('special',),
        'Delimiter': ('fg',), 'Bracket': ('fg',),
        'CursorLine': (None, 'line'), 'CursorColumn': (None, 'line'),
        'CursorLineNr': ('accent',), 'LineNr': ('gutter_normal',),
        'ColorColumn': (None, 'line'), 'FloatBorder': ('comment', 'panel_bg'),
        'Visual': (None, 'selection_bg'),
        'DiagnosticWarn': ('warning',), 'DiagnosticHint': ('regexp',),
        'DiagnosticInfo': ('tag',),
    }
    # Avoid the template's subdued gutter blue in ANSI syntax and tool sync.
    ansi = ['bg', 'markup', 'string', 'func', 'entity', 'constant',
            'regexp', 'fg', 'comment', 'error', 'vcs_added', 'accent',
            'vcs_modified', 'constant', 'tag', 'fg']
    lines = ["if vim.go.bg == 'dark' then"]
    for mode in ('dark', 'light'):
        if mode == 'light':
            lines.append('else')
        p = AYU_PALETTES[AYU_THEMES[name][mode]]
        for group, values in roles.items():
            attrs = []
            for attr, role in zip(('fg', 'bg'), values):
                if role:
                    c = fixed_color(p[role])
                    attrs.append("%s = { '%s', %d }" % (attr, c['hex'], c['cterm']))
            if group == 'CursorLineNr':
                attrs.append('bold = true')
            if group == 'Comment':
                attrs.append('italic = true')
            lines.append('  hlgroups.%s = { %s }' % (group, ', '.join(attrs)))
        for i, role in enumerate(ansi):
            lines.append("  vim.g.terminal_color_%d = '%s'" % (i, p[role].lower()))
    lines.append('end')
    marker = '-- Set highlight groups {{{1'
    if src.count(marker) != 1:
        raise ValueError('cockatoo highlight application marker changed')
    src = src.replace(marker, '\n'.join(lines) + '\n\n' + marker)
    forced = {'ayu-dark': 'dark', 'ayu-mirage': 'dark', 'ayu-light': 'light'}
    if name in forced:
        src = src.replace("vim.cmd.hi('clear')",
                          "vim.o.background = '%s'\nvim.cmd.hi('clear')" % forced[name])
    return src


def build(theme, mode):
    if theme in AYU_THEMES:
        return build_ayu(AYU_THEMES[theme][mode])
    t = THEMES[theme]
    out = {}
    for slot, (fam, ds, dl, ls, ll) in ROLE.items():
        if fam == 'n':
            hue = t['neutral']
        else:
            hue = t['hues'][fam] + HUE_OFF.get(slot, 0)
        smul = t['sat'].get(fam if fam != 'n' else 'default', t['sat'].get('default', 1.0))
        s, l = (ds, dl) if mode == 'dark' else (ls, ll)
        rgb = hsl(hue, min(s * smul, 100), l)
        out[slot] = dict(hex=hexof(rgb), cterm=nearest_cterm(rgb), rgb=rgb,
                         h=hue, s=min(s * smul, 100), l=l)
    return out


# ------------------------------------------------------------------- constraints
TEXT_SLOTS = [
    'c_smoke', 'c_beige', 'c_pigeon',
    'c_yellow', 'c_earth', 'c_orange', 'c_ochre', 'c_pink', 'c_scarlet',
    'c_tea', 'c_aqua', 'c_turquoise', 'c_flashlight', 'c_skyblue',
    'c_cerulean', 'c_lavender', 'c_purple', 'c_magenta',
]
BG_SLOTS = ['c_jeans', 'c_ocean', 'c_deepsea']
TEXT_BGS = {slot: BG_SLOTS for slot in TEXT_SLOTS}
# (fg, bg, min ratio): text on accent backgrounds
ON_ACCENT = [
    ('c_black', 'c_orange', 4.5), ('c_space', 'c_smoke', 4.5),
    ('c_space', 'c_flashlight', 4.5), ('c_space', 'c_orange', 4.5),
    ('c_space', 'c_turquoise', 4.5), ('c_space', 'c_yellow', 4.5),
    ('c_jeans', 'c_pigeon', 4.5), ('c_jeans', 'c_ochre', 4.5),
    ('c_smoke', 'c_thunder', 4.5),
]
# (fg, bg, min ratio): text on blend backgrounds
BLEND_PAIRS = [
    ('c_tea', 'c_tea_blend', 4.5), ('c_tea', 'c_aqua_blend', 4.5),
    ('c_lavender', 'c_lavender_blend', 4.5),
    ('c_scarlet', 'c_scarlet_blend', 4.5),
    ('c_scarlet', 'c_wine_blend', 4.5), ('c_smoke', 'c_smoke_blend', 4.5),
    ('c_pigeon', 'c_smoke_blend', 3.0), ('c_yellow', 'c_yellow_blend', 3.0),
]


def constraints():
    """Yield (kind, slot_a, slot_b_or_None, min_ratio).

    kind also encodes which side the tuner may adjust:
    'text'/'blend' -> adjust a; 'pair_fg' -> adjust a; 'pair_bg' -> adjust b.
    """
    for slot in TEXT_SLOTS:
        yield ('text', slot, None, 3.0 if slot == 'c_steel' else 4.5)
    # wine is the deep crimson of delete/diff contexts: tiered accordingly
    yield ('pair_fg', 'c_wine', 'c_jeans', 3.2)
    for fg, bg, need in ON_ACCENT:
        yield ('pair_bg', fg, bg, need)
    for fg, bg, need in BLEND_PAIRS:
        yield ('pair_fg', fg, bg, need)
    yield ('pair_fg', 'c_wine', 'c_wine_blend', 3.0)
    for slot in (s for s in ROLE if s.endswith('_blend')):
        yield ('blend', slot, None, 1.12)


def ratio(pal, kind, a, b):
    if kind == 'text':
        return min(contrast(pal[a]['rgb'], pal[bg]['rgb']) for bg in TEXT_BGS[a])
    if kind == 'blend':
        return contrast(pal[a]['rgb'], pal['c_jeans']['rgb'])
    return contrast(pal[a]['rgb'], pal[b]['rgb'])


def tune(theme, mode, pal):
    """Nudge slot lightness minimally until every constraint passes."""
    cons = list(constraints())
    fixed = []  # kind, a, b, need, value
    slack = 1.04  # tune past the threshold so values are not knife-edge
    for _ in range(120):
        fixed = [(k, a, b, need, ratio(pal, k, a, b)) for k, a, b, need in cons]
        bad = [c for c in fixed if c[4] < c[3] * slack]
        if not bad:
            return []
        progress = False
        for kind, a, b, need, _ in bad:
            # choose adjustable slot and direction (away from counterpart)
            if kind in ('text', 'blend', 'pair_fg'):
                slot, other = a, b
            else:  # pair_bg
                slot, other = b, a
            if kind == 'blend':
                other = 'c_jeans'
            if kind == 'text':
                # move away from the bg it fails against most
                worst = min(TEXT_BGS[a],
                            key=lambda bg: contrast(pal[a]['rgb'], pal[bg]['rgb']))
                other = worst
            ol = pal[other]['l'] if other else (95 if mode == 'light' else 15)
            cur = pal[slot]['l']
            step = 1 if cur > ol else -1
            new_l = cur + step
            if new_l < 8 or new_l > 93:
                continue
            pal[slot]['l'] = new_l
            pal[slot]['rgb'] = hsl(pal[slot]['h'], pal[slot]['s'], new_l)
            pal[slot]['hex'] = hexof(pal[slot]['rgb'])
            pal[slot]['cterm'] = nearest_cterm(pal[slot]['rgb'])
            progress = True
        if not progress:
            break
    fixed = [(k, a, b, need, ratio(pal, k, a, b)) for k, a, b, need in cons]
    return [f'{k}:{a}{" on " + b if b else ""} {v:.2f} < {need}'
            for k, a, b, need, v in fixed if v < need]


# ------------------------------------------------------------------- rendering


def render(name, pal, template):
    if set(re.findall(r'^local (c_\w+)$', template, re.M)) != set(SLOTS):
        raise ValueError('cockatoo palette declarations changed')
    head = (
        '-- Name:         %s\n'
        '-- Description:  %s\n'
        '-- Author:       Bekaboo <kankefengjing@gmail.com>\n'
        '-- Maintainer:   Bekaboo <kankefengjing@gmail.com>\n'
        '-- License:      GPL-3.0\n'
        '-- Generated:    tools/gen_themes.py; edit the generator instead\n'
        % (name, THEMES[name]['desc'])
    )
    if name in AYU_THEMES:
        head += ('-- Palette:      Ayu by dempfi; adapted from Shatur/neovim-ayu\n'
                 '-- Attribution:  colors/licenses/README.md\n')
    src, count = re.subn(r'\A(-- Name:.*?\n\n)', head + '\n', template, count=1, flags=re.S)
    if count != 1 or template.count("vim.g.colors_name = 'cockatoo'") != 1:
        raise ValueError('cockatoo header or colors_name changed')
    src = src.replace("vim.g.colors_name = 'cockatoo'",
                      "vim.g.colors_name = '%s'" % name)
    # error surfaces (incl. statusline on selection bg) use the AA-vivid
    # scarlet; wine is reserved for deep-crimson delete/diff contexts
    src = src.replace('DiagnosticError = { fg = c_wine }',
                      'DiagnosticError = { fg = c_scarlet }')
    src = src.replace('DiagnosticUnderlineError = { undercurl = true, sp = c_wine }',
                      'DiagnosticUnderlineError = { undercurl = true, sp = c_scarlet }')
    src = src.replace('StatusLineDiagnosticError = { fg = c_wine, bg = c_deepsea }',
                      'StatusLineDiagnosticError = { fg = c_scarlet, bg = c_deepsea }')

    width = max(len(s) for s in SLOTS)
    lines = ["if vim.go.bg == 'dark' then"]
    for mode in ('dark', 'light'):
        if mode == 'light':
            lines.append('else')
        for slot in SLOTS:
            p = pal[mode][slot]
            lines.append('  %s = { \'%s\', %s }'
                         % (slot.ljust(width), p['hex'], str(p['cterm']).ljust(3)))
    lines.append('end')
    block = '\n'.join(lines)

    src, count = re.subn(
        r"(local c_smoke_blend\n\n)(if vim\.go\.bg == 'dark' then.*?\nend)(\n-- stylua: ignore end)",
        lambda m: m.group(1) + block + m.group(3),
        src,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise ValueError('cockatoo palette block changed')
    if name in AYU_THEMES:
        src = render_ayu(name, src)
    return src


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('names', nargs='*', help='theme names (default: all)')
    ap.add_argument('--check', action='store_true',
                    help='validate palette constraints and rendering; do not write')
    args = ap.parse_args()

    names = args.names or list(THEMES)
    unknown = [n for n in names if n not in THEMES]
    if unknown:
        ap.error(f'unknown theme(s): {", ".join(unknown)}')

    template = TEMPLATE_PATH.read_text()
    bad_total = {}
    rendered = {}
    for name in names:
        pal = {m: build(name, m) for m in ('dark', 'light')}
        fails = {}
        for mode in ('dark', 'light'):
            if name in AYU_THEMES:
                # Keep upstream syntax colors, including deliberately muted
                # light accents. Only require AA for the main reading surface.
                value = contrast(pal[mode]['c_smoke']['rgb'], pal[mode]['c_jeans']['rgb'])
                fails[mode] = [] if value >= 4.5 else [f'Normal contrast {value:.2f} < 4.5']
                print(f'{name} {mode}: Normal contrast {value:.2f}; fixed upstream palette')
            else:
                fails[mode] = tune(name, mode, pal[mode])
            bad_total[(name, mode)] = fails[mode]
        if name in AYU_THEMES:
            rendered[name] = render(name, pal, template)
            continue
        print('=== %s ===' % name)
        for mode in ('dark', 'light'):
            vals = [
                (ratio(pal[mode], k, a, b) / need, k, a, b)
                for k, a, b, need in constraints()
            ]
            margin, kind, a, b = min(vals)
            where = f'{kind} {a}' + (f' on {b}' if b else '')
            print(f'  {mode}: min margin {margin:.2f}x ({where})'
                  + ('' if not fails[mode] else '  !! ' + '; '.join(fails[mode])))
        rendered[name] = render(name, pal, template)

    if any(bad_total.values()):
        print('CONTRAST FAILURES PRESENT', file=sys.stderr)
        sys.exit(1)
    if not args.check:
        for name, src in rendered.items():
            (REPO / 'colors' / f'{name}.lua').write_text(src)
    print('all contrast checks passed')


if __name__ == '__main__':
    main()
