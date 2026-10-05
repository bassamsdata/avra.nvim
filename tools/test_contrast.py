#!/usr/bin/env python3
"""Regression checks for contrast math, actual exports, and failure detection."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import check_contrast as audit


class ContrastTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('nvim'), 'requires Neovim')
    def test_insert_indicator_contrast_across_all_themes(self):
        with tempfile.TemporaryDirectory(prefix='avra-mode-contrast-') as directory:
            for path in sorted((audit.REPO / 'colors').glob('*.lua')):
                for mode in ('dark', 'light'):
                    snapshot = audit.capture(shutil.which('nvim'), path.stem, mode, Path(directory))
                    rows = [c for c in audit.audit(snapshot)['checks']
                            if c['label'] == 'Neovim MyModeInsertLineNr']
                    self.assertEqual(len(rows), 1)
                    self.assertTrue(rows[0]['passed'], f'{path.stem}/{mode}: {rows[0]}')
                    # Ensure the gate detects an unreadable indicator.
                    if path.stem == 'seaglass':
                        broken = copy.deepcopy(snapshot)
                        broken['highlights']['MyModeInsertLineNr']['fg'] = snapshot['highlights']['Normal']['bg']
                        failures = [c for c in audit.audit(broken)['checks']
                                    if c['label'] == 'Neovim MyModeInsertLineNr' and not c['passed']]
                        self.assertEqual(len(failures), 1)

    def test_wcag_reference_pairs_and_threshold(self):
        self.assertEqual(audit.contrast('#000000', '#ffffff'), 21.0)
        self.assertEqual(audit.contrast('#777777', '#777777'), 1.0)
        self.assertAlmostEqual(audit.contrast('#777777', '#ffffff'), 4.478089453577214)
        self.assertFalse(audit.check('gray', '#777777', '#ffffff')['passed'])
        self.assertTrue(audit.check('gray', '#767676', '#ffffff')['passed'])
        self.assertAlmostEqual(audit.contrast('#ff0000', '#ffffff'), 3.9984767707539985)

    def test_report_preserves_data_and_emits_matrix(self):
        result = dict(name='sample</script>', requested_background='dark', background='dark',
                      checks=[audit.check('focus', '#ffffff', '#000000'),
                              audit.check_opacity('dialog', '#ffffff', 'none')],
                      skipped=[], colors=['#000000', '#ffffff'], groups=1)
        self.assertEqual(audit.matrix(result)[0]['ratio'], 21)
        with tempfile.TemporaryDirectory(prefix='avra-report-test-') as directory:
            report = Path(directory) / 'report.html'
            audit.write_report(report, [result])
            content = report.read_text()
            self.assertIn('sample\\u003c/script>', content)
            payload = content.split('type="application/json">', 1)[1].split('</script>', 1)[0]
            self.assertEqual(json.loads(payload), [result])

    @unittest.skipUnless(shutil.which('nvim'), 'requires Neovim')
    def test_actual_ayu_exports_and_original_regression(self):
        with tempfile.TemporaryDirectory(prefix='avra-contrast-test-') as directory:
            for name, mode in (('ayu-dark', 'dark'), ('ayu-mirage', 'dark'),
                               ('ayu-light', 'light'), ('ayu', 'dark'), ('ayu', 'light')):
                snapshot = audit.capture(shutil.which('nvim'), name, mode, Path(directory))
                for key in ('opencode', 'transparent_opencode'):
                    theme = snapshot[key]
                    for surface in ('primary', 'warning'):
                        self.assertGreaterEqual(audit.contrast(theme['selectedListItemText'], theme[surface]), 4.5)
                self.assertFalse(any(not c['passed'] and c['critical']
                                     for c in audit.audit(snapshot)['checks']))
                # The old export must fail this exact same check: a useful
                # gate should reproduce the reported bug, not just test itself.
                broken = copy.deepcopy(snapshot)
                for key in ('opencode', 'transparent_opencode'):
                    broken[key]['selectedListItemText'] = snapshot['palette']['selection_foreground']
                failures = [c for c in audit.audit(broken)['checks']
                            if c['critical'] and not c['passed'] and 'focused text' in c['label']]
                self.assertTrue(failures, name + '/' + mode)

    @unittest.skipUnless(shutil.which('nvim'), 'requires Neovim')
    def test_all_theme_menus_remain_opaque_with_transparency(self):
        with tempfile.TemporaryDirectory(prefix='avra-opacity-test-') as directory:
            for path in sorted((audit.REPO / 'colors').glob('*.lua')):
                for mode in ('dark', 'light'):
                    snapshot = audit.capture(shutil.which('nvim'), path.stem, mode, Path(directory))
                    transparent = snapshot['transparent_opencode']
                    self.assertEqual(transparent['background'], 'none')
                    for surface in ('backgroundPanel', 'backgroundMenu'):
                        self.assertEqual(transparent[surface], snapshot['opencode'][surface])
                        self.assertTrue(audit.check_opacity(surface, transparent['text'],
                                                          transparent[surface])['passed'])
                    # Reproduce the former transparent-dialog export and ensure
                    # the audit blocks it even when a fallback color contrasts.
                    broken = copy.deepcopy(snapshot)
                    broken['transparent_opencode']['backgroundPanel'] = 'none'
                    failures = [c for c in audit.audit(broken)['checks']
                                if c['critical'] and not c['passed'] and 'opacity' in c['label']]
                    self.assertEqual(len(failures), 1, path.stem + '/' + mode)
                    self.assertIsNone(failures[0]['ratio'])

    @unittest.skipUnless(shutil.which('nvim'), 'requires Neovim')
    def test_runtime_contrast_and_opposing_focus_surfaces(self):
        script = """
vim.opt.runtimepath:prepend(vim.env.AVRA_AUDIT_REPO)
local contrast = require('my.utils.contrast')
assert(contrast.ratio('#000000', '#ffffff') == 21)
assert(contrast.ratio('#777777', '#ffffff') < 4.5)
assert(contrast.ratio('#767676', '#ffffff') >= 4.5)
local text = contrast.foreground({ '#000000' }, { '#ffffff', '#000000' })
assert(text == '#ffffff')
local warning = contrast.background(text, '#f09276')
assert(contrast.ratio(text, warning) >= 4.5)
assert(contrast.background('#000000', '#f09276') == '#f09276')
vim.cmd.colorscheme('seaglass')
vim.api.nvim_set_hl(0, 'Purple', { fg = '#244736' })
require('my.core.modecolor').setup()
local number = vim.api.nvim_get_hl(0, { name = 'MyModeInsertLineNr' })
local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
assert(contrast.ratio('#244736', string.format('#%06x', normal.bg)) < 4.5)
assert(contrast.ratio(string.format('#%06x', number.fg),
  string.format('#%06x', normal.bg)) >= 4.5)
"""
        with tempfile.TemporaryDirectory(prefix='avra-contrast-lua-') as directory:
            env = os.environ.copy()
            env['AVRA_AUDIT_REPO'] = str(audit.REPO)
            for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
                env['XDG_' + kind + '_HOME'] = str(Path(directory) / kind.lower())
            source = Path(directory) / 'check.lua'
            source.write_text(script + "\nvim.cmd('qa!')\n")
            result = subprocess.run(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE',
                                     '-l', str(source)],
                                    env=env, text=True, capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('Error', result.stderr)


if __name__ == '__main__':
    unittest.main()
