#!/usr/bin/env python3
"""Audit loaded Neovim highlights and OpenCode exports, without changing configs.

make accessibility-check                         # block critical regressions
python3 tools/check_contrast.py --strict           # require all modeled text AA
python3 tools/check_contrast.py --report /tmp/avra-contrast.html

Opaque sRGB WCAG 2.2 contrast: normal-sized terminal text targets 4.5:1.
Every color pair is available in the report matrix. Only combinations modeled
as foreground/background roles are graded; same-color reuse is legitimate.
This is a color audit, not a claim of complete WCAG conformance.
"""
import argparse
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
PALETTE_GROUPS = set('Yellow Earth Orange Scarlet Ochre Wine Pink Tea Flashlight '
                     'Aqua Cerulean SkyBlue Turquoise Lavender Magenta Purple Thunder '
                     'White Beige Pigeon Steel Smoke Iron Deepsea Ocean Space Black'.split())


def luminance(color):
    values = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
              for v in values]
    return sum(v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(foreground, background):
    a, b = luminance(foreground), luminance(background)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def hex_color(value, fallback):
    return f'#{value:06x}' if isinstance(value, int) else fallback


def check(label, foreground, background, critical=False, context='', minimum=4.5):
    ratio = contrast(foreground, background)
    return dict(label=label, foreground=foreground, background=background,
                ratio=ratio, minimum=minimum, passed=ratio >= minimum,
                critical=critical, context=context)


def check_opacity(label, foreground, background):
    return dict(label=label, foreground=foreground, background=background,
                ratio=None, minimum=None,
                passed=re.fullmatch(r'#[0-9a-fA-F]{6}', background) is not None,
                critical=True,
                context='Menu surfaces must be opaque to hide underlying text')


def capture(nvim, name, mode, directory):
    # A fresh process per variant prevents stale highlights/ANSI globals from
    # previous themes concealing coverage errors. No user init or UI is loaded.
    request = directory / 'request.json'
    output = directory / 'snapshot.json'
    output.unlink(missing_ok=True)
    request.write_text(json.dumps(dict(name=name, background=mode)))
    env = os.environ.copy()
    for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
        env['XDG_' + kind + '_HOME'] = str(directory / kind.lower())
    env['AVRA_AUDIT_REQUEST'] = str(request)
    env['AVRA_AUDIT_OUTPUT'] = str(output)
    env['AVRA_AUDIT_REPO'] = str(REPO)
    script = """
vim.opt.runtimepath:prepend(vim.env.AVRA_AUDIT_REPO)
local request = vim.json.decode(table.concat(vim.fn.readfile(vim.env.AVRA_AUDIT_REQUEST), '\\n'))
local snapshot = require('my.plugin.appearance.audit').snapshot(request.name, request.background)
vim.fn.writefile({ vim.json.encode(snapshot) }, vim.env.AVRA_AUDIT_OUTPUT)
"""
    result = subprocess.run(
        [nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
         '+lua ' + script.replace('\n', ' '), '+qa!'],
        env=env, cwd=directory, text=True, capture_output=True, timeout=30,
    )
    if result.returncode or not output.exists() or 'Error' in result.stderr:
        raise RuntimeError(f'{name}/{mode}: {result.stderr.strip()}')
    snapshot = json.loads(output.read_text())
    output.unlink()
    if snapshot['name'] != name:
        raise RuntimeError(f'{name} loaded as {snapshot["name"]}')
    return snapshot


def audit(snapshot):
    highlights = snapshot['highlights']
    palette = snapshot['palette']
    normal_fg, normal_bg = palette['foreground'], palette['background']
    rows, skipped = [], []

    def effective(group, parent='Normal'):
        base = highlights.get(parent, {})
        attrs = highlights.get(group, {})
        fg = hex_color(attrs.get('fg'), hex_color(base.get('fg'), normal_fg))
        bg = hex_color(attrs.get('bg'), hex_color(base.get('bg'), normal_bg))
        if attrs.get('reverse'):
            fg, bg = bg, fg
        return fg, bg

    # These reading surfaces have explicit regression gates. Other inherited
    # syntax and plugin roles remain visible findings without recoloring Ayu.
    for group in ('Normal', 'NormalFloat'):
        fg, bg = effective(group)
        rows.append(check('Neovim ' + group, fg, bg, critical=True))
    for group in sorted(highlights):
        if group in ('Normal', 'NormalFloat'):
            continue
        if group in PALETTE_GROUPS:
            continue  # palette helper highlights remain in the all-color matrix
        attrs = highlights[group]
        if attrs.get('blend', 0) > 0:
            skipped.append(group + ': blended overlay needs a rendered backdrop')
            continue
        if not attrs.get('fg') and not attrs.get('bg') and not attrs.get('reverse'):
            continue  # styling-only groups do not introduce color pairs
        parent = 'Normal'
        if group.startswith('Pmenu'):
            parent = 'Pmenu'
        elif group.startswith('TelescopePrompt'):
            parent = 'TelescopePromptNormal'
        elif group.startswith('Telescope'):
            parent = 'TelescopeNormal'
        elif group.startswith('DapUI'):
            parent = 'NormalFloat'
        fg, bg = effective(group, parent)
        if group.endswith(('Border', 'Split', 'Separator')):
            rows.append(check('Neovim ' + group, fg, bg, minimum=3.0,
                              context='Non-text indicator; decorative separators may be exempt'))
            continue
        if group in ('PmenuThumb', 'PmenuSbar', 'ColorColumn', 'CursorLine'):
            parent_bg = effective(parent)[1]
            rows.append(check('Neovim ' + group, bg, parent_bg, minimum=3.0,
                              context='Non-text surface; decorative treatments may be exempt'))
            continue
        rows.append(check('Neovim ' + group, fg, bg,
                          critical=group == 'MyModeInsertLineNr',
                          context='Inherited surface: ' + parent))

    # Selection/search overlays can cover syntax text as well as Normal text.
    # This catches combinations hidden by checking palette slots in isolation.
    for surface in ('Visual', 'Search', 'CursorLine'):
        overlay = highlights.get(surface, {})
        if overlay.get('fg') is not None or overlay.get('reverse'):
            continue
        if overlay.get('bg') is None:
            continue
        bg = hex_color(overlay['bg'], normal_bg)
        for group in sorted(highlights):
            attrs = highlights[group]
            if group.startswith('@') and attrs.get('fg') is not None:
                fg = hex_color(attrs['fg'], normal_fg)
                rows.append(check(f'Neovim {group} on {surface}', fg, bg,
                                  context='Syntax text beneath a background overlay'))

    for mode, key in (('opaque', 'opencode'), ('transparent', 'transparent_opencode')):
        theme = snapshot[key]
        for surface in ('backgroundPanel', 'backgroundMenu'):
            rows.append(check_opacity(f'OpenCode {mode} {surface} opacity',
                                      theme['text'], theme[surface]))
        for foreground in ('border', 'borderActive', 'borderSubtle'):
            for background in ('backgroundPanel', 'backgroundMenu'):
                if theme[background] != 'none':
                    rows.append(check(f'OpenCode {mode} {foreground} against {background}',
                                      theme[foreground], theme[background], minimum=3.0,
                                      context='Non-text indicator target; decorative separators may be exempt'))
        for background in ('primary', 'warning'):
            rows.append(check(f'OpenCode {mode} focused text on {background}',
                              theme['selectedListItemText'], theme[background],
                              critical=True,
                              context='Command dialog/slash suggestions; paste badge'))
        for background in ('background', 'backgroundPanel', 'backgroundElement', 'backgroundMenu'):
            if theme[background] == 'none':
                skipped.append(f'OpenCode {mode} {background}: terminal backdrop unknown')
                continue
            for foreground in ('text', 'textMuted', 'primary', 'secondary', 'accent',
                               'error', 'warning', 'success', 'info'):
                rows.append(check(f'OpenCode {mode} {foreground} on {background}',
                                  theme[foreground], theme[background],
                                  critical=foreground == 'text'))
            for foreground in sorted(theme):
                if foreground.startswith(('syntax', 'markdown')) and foreground not in ('markdownHorizontalRule',):
                    rows.append(check(f'OpenCode {mode} {foreground} on {background}',
                                      theme[foreground], theme[background]))
        for foreground, background in (
            ('diffAdded', 'diffAddedBg'), ('diffRemoved', 'diffRemovedBg'),
            ('diffContext', 'diffContextBg'), ('diffHunkHeader', 'diffContextBg'),
            ('diffLineNumber', 'diffAddedLineNumberBg'),
            ('diffLineNumber', 'diffRemovedLineNumberBg'),
        ):
            rows.append(check(f'OpenCode {mode} {foreground} on {background}',
                              theme[foreground], theme[background]))

    # Collect every distinct loaded/exported RGB color for an exhaustive,
    # ungraded matrix. It includes line/border/special/ANSI colors as well.
    colors = set(palette['colors']) | {normal_fg, normal_bg}
    for attrs in highlights.values():
        for attr in ('fg', 'bg', 'sp'):
            if isinstance(attrs.get(attr), int):
                colors.add(hex_color(attrs[attr], normal_bg))
    for key in ('opencode', 'transparent_opencode'):
        colors.update(v for v in snapshot[key].values() if v.startswith('#'))
    return dict(name=snapshot['name'], requested_background=snapshot['requested_background'],
                background=snapshot['background'], checks=rows, colors=sorted(colors),
                skipped=skipped, groups=len(highlights))


def matrix(result):
    return [dict(a=a, b=b, ratio=contrast(a, b))
            for a, b in itertools.combinations(result['colors'], 2)]


def write_report(path, results):
    payload = json.dumps(results).replace('<', '\\u003c')
    template = """<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Avra color contrast audit</title>
<style>
body{font:15px system-ui;margin:2rem;color:#18202a;background:#fafafa}h1{font-size:26px}
select,input{font:inherit;padding:.4rem;margin:.3rem}table{border-collapse:collapse;width:100%}
th,td{text-align:left;padding:.5rem;border-bottom:1px solid #ddd}.sample{font-family:monospace;padding:.4rem}
.fail{color:#a31515}.pass{color:#14602c}small{display:block;margin:1rem 0;color:#424b57}
.matrix{overflow:auto}.matrix table{width:auto;font:11px monospace}.matrix td{min-width:42px;text-align:center}
</style><h1>Avra color contrast audit</h1>
<p>WCAG 2.2 normal text target: 4.5:1. Critical reading/focus and menu opacity failures block the default check.
Other findings include original soft syntax palettes. This is a color audit, not full WCAG conformance.</p>
<label>Theme <select id="theme"></select></label>
<label><input id="failures" type="checkbox" checked> Findings only</label>
<label>Filter <input id="filter" placeholder="focused, String, Visual…"></label>
<p id="summary"></p><small id="skipped"></small>
<table><thead><tr><th>Rendered role</th><th>Preview</th><th>Ratio</th><th>Result</th></tr></thead><tbody id="rows"></tbody></table>
<details><summary>All loaded colors against each other (exploration)</summary>
<p>Every distinct opaque RGB pair. Matrix cells are ratios, not failures: many pairs never form text/background combinations.</p>
<div class="matrix" id="matrix"></div></details>
<script id="data" type="application/json">PAYLOAD</script><script>
const results=JSON.parse(document.getElementById('data').textContent);
const picker=document.getElementById('theme'), failures=document.getElementById('failures'), filter=document.getElementById('filter');
results.forEach((r,i)=>{const o=document.createElement('option');o.value=i;o.textContent=r.name+' / requested '+r.requested_background+' / actual '+r.background;picker.append(o)});
function lum(hex){const c=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return c.reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0)}
function ratio(a,b){a=lum(a);b=lum(b);return(Math.max(a,b)+.05)/(Math.min(a,b)+.05)}
function render(){
 const r=results[picker.value];if(!r){document.getElementById('summary').textContent='No snapshots captured; inspect the command output for load errors.';return}
 const bad=r.checks.filter(c=>!c.passed), critical=bad.filter(c=>c.critical);
document.getElementById('summary').textContent=r.groups+' highlight groups; '+r.checks.length+' modeled checks; '+critical.length+' critical failures; '+bad.length+' total findings; '+r.colors.length+' distinct colors.';
 document.getElementById('skipped').textContent='Unmeasured: '+r.skipped.join('; ');
 const rows=document.getElementById('rows');rows.replaceChildren();
 r.checks.filter(c=>(!failures.checked||!c.passed)&&c.label.toLowerCase().includes(filter.value.toLowerCase())).sort((a,b)=>a.ratio-b.ratio).forEach(c=>{
  const tr=document.createElement('tr'), label=document.createElement('td');label.textContent=c.label;label.title=c.context;tr.append(label);
  const sample=document.createElement('td'), span=document.createElement('span');span.className='sample';span.style.color=c.foreground;span.style.background=c.background;span.textContent=c.ratio===null?'Panel background: '+c.background:'Focused item / '+c.foreground+' on '+c.background;sample.append(span);tr.append(sample);
  const score=document.createElement('td');score.textContent=c.ratio===null?'Opaque surface required':c.ratio.toFixed(2)+':1 / target '+c.minimum+':1';tr.append(score);
  const state=document.createElement('td');state.className=c.passed?'pass':'fail';state.textContent=c.passed?'Pass':c.critical?'Critical failure':'Finding';tr.append(state);rows.append(tr);
 });
 const table=document.createElement('table'), head=document.createElement('tr');head.append(document.createElement('th'));
 r.colors.forEach(c=>{const th=document.createElement('th');th.textContent=c;head.append(th)});table.append(head);
 r.colors.forEach(a=>{const tr=document.createElement('tr'), th=document.createElement('th');th.textContent=a;tr.append(th);r.colors.forEach(b=>{const td=document.createElement('td');td.textContent=ratio(a,b).toFixed(2);td.style.color=ratio('#000000',b)>=4.5?'#000000':'#ffffff';td.style.background=b;td.style.borderLeft='4px solid '+a;td.title=a+' on '+b;tr.append(td)});table.append(tr)});
 document.getElementById('matrix').replaceChildren(table);
}
[picker,failures,filter].forEach(e=>e.addEventListener('input',render));render();
</script></html>"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(template.replace('PAYLOAD', payload))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='colorscheme names (default: every colors/*.lua)')
    parser.add_argument('--nvim', default='nvim', help='Neovim executable')
    parser.add_argument('--strict', action='store_true', help='fail on every modeled text finding')
    parser.add_argument('--report', type=Path, help='write an interactive HTML report')
    parser.add_argument('--json', type=Path, help='write checks and all-pair matrices as JSON')
    args = parser.parse_args()
    nvim = shutil.which(args.nvim)
    if not nvim:
        parser.error('Neovim is required')
    available = {p.stem for p in (REPO / 'colors').glob('*.lua')}
    names = args.names or sorted(available)
    if set(names) - available:
        parser.error('unknown themes: ' + ', '.join(sorted(set(names) - available)))
    results, errors = [], []
    with tempfile.TemporaryDirectory(prefix='avra-contrast-') as directory:
        for name in names:
            for mode in ('dark', 'light'):
                try:
                    result = audit(capture(nvim, name, mode, Path(directory)))
                except (RuntimeError, subprocess.SubprocessError, ValueError) as err:
                    errors.append(str(err))
                    print('ERROR:', err)
                    continue
                results.append(result)
                bad = [c for c in result['checks'] if not c['passed']]
                critical = [c for c in bad if c['critical']]
                print(f'{name}/{mode}: {len(critical)} critical failures, {len(bad)} findings '
                      f'in {len(result["checks"])} checks; {len(result["colors"])} colors')
                for row in critical:
                    if row['ratio'] is None:
                        print(f'  FAIL {row["label"]}: {row["background"]}; {row["context"]}')
                        continue
                    print(f'  FAIL {row["label"]}: {row["foreground"]} on '
                          f'{row["background"]} = {row["ratio"]:.3f}:1 < 4.5:1')
    if args.report:
        write_report(args.report, results)
        print('Report:', args.report.resolve())
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps([dict(r, matrix=matrix(r)) for r in results], indent=2) + '\n')
        print('JSON:', args.json.resolve())
    failed = errors or any(not c['passed'] and (args.strict or c['critical'])
                           for result in results for c in result['checks'])
    if failed:
        print('Accessibility check failed. Inspect the report for measured pairs and menu opacity.')
    else:
        print('Critical contrast/opacity checks passed; additional findings remain inspectable in the report.')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
