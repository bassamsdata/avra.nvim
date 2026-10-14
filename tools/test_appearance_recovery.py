#!/usr/bin/env python3
"""Exercise persistent tool themes across real Neovim app namespaces."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = """
vim.opt.runtimepath:prepend(vim.env.AVRA_TEST_REPO)
local warnings = {}
vim.notify = function(message) warnings[#warnings + 1] = message end
-- Headless tests have no terminal UI or tool processes to reload.
vim.system = function(command)
  assert(command[1] == 'pkill' and command[2] == '-USR2')
  return {}
end
vim.cmd.colorscheme(vim.env.AVRA_TEST_THEME or 'ayu-dark')
local palette = require('my.plugin.appearance.ghostty').palette(
  vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
)
local result = { warnings = warnings }
for _, name in ipairs({ 'btop', 'opencode' }) do
  local tool = require('my.plugin.appearance.' .. name)
  tool.available = function() return true end
  if vim.env.AVRA_TEST_ACTION == 'reset' then
    tool.reset()
  else
    result[name] = tool.sync(palette, false)
  end
end
vim.fn.writefile({ vim.json.encode(result) }, vim.env.AVRA_TEST_OUTPUT)
"""


@unittest.skipUnless(shutil.which('nvim'), 'requires Neovim')
class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='avra-recovery-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.script = self.root / 'driver.lua'
        self.script.write_text(SCRIPT)
        self.config = self.root / 'config'
        self.state = self.root / 'state'
        self.state.mkdir()
        for tool in ('btop', 'opencode'):
            (self.config / tool).mkdir(parents=True)
        self.btop = self.config / 'btop/btop.conf'
        self.opencode = self.config / 'opencode/tui.jsonc'
        self.original_btop = '# keep this\ncolor_theme = "Default"\nupdate_ms = 2000\n'
        self.original_opencode = '{\n  // keep this\n  "theme": "system",\n  "scroll_speed": 3,\n}\n'
        self.btop.write_text(self.original_btop)
        self.opencode.write_text(self.original_opencode)

    def run_nvim(self, app, action='sync', theme='ayu-dark'):
        env = os.environ.copy()
        for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
            env['XDG_' + kind + '_HOME'] = str(self.root / kind.lower())
        output = self.root / 'result.json'
        env.update(NVIM_APPNAME=app, AVRA_TEST_REPO=str(REPO),
                   AVRA_TEST_OUTPUT=str(output), AVRA_TEST_ACTION=action,
                   AVRA_TEST_THEME=theme, NVIM_LOG_FILE=str(self.root / 'nvim.log'))
        result = subprocess.run(
            ['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
             '-l', str(self.script)],
            env=env, cwd=self.root, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('Error', result.stderr)
        self.assertTrue(output.exists(), result.stderr)
        data = json.loads(output.read_text())
        output.unlink()
        return data

    def journal(self, tool):
        return self.config / tool / 'avra-nvim-sync.json'

    def make_legacy(self, app='nvim.avra'):
        result = self.run_nvim(app)
        self.assertEqual(result['warnings'], [])
        directory = self.state / app
        directory.mkdir(exist_ok=True)
        for tool in ('btop', 'opencode'):
            self.journal(tool).rename(directory / (tool + '-sync.json'))
        return directory

    def assert_restored(self):
        self.assertEqual(self.btop.read_text(), self.original_btop)
        self.assertEqual(self.opencode.read_text(), self.original_opencode)
        self.assertFalse((self.config / 'opencode/themes/avra-nvim.json').exists())
        for tool in ('btop', 'opencode'):
            self.assertFalse(self.journal(tool).exists())

    def test_shared_state_across_app_names_and_reset(self):
        self.assertEqual(self.run_nvim('nvim.avra')['warnings'], [])
        result = self.run_nvim('nvim', theme='ayu-light')
        self.assertTrue(result['btop'])
        self.assertTrue(result['opencode'])
        self.assertEqual(result['warnings'], [])
        self.assertEqual(self.run_nvim('nvim.avra', 'reset')['warnings'], [])
        self.assert_restored()

    def test_legacy_migration_retains_originals_and_checksums(self):
        directory = self.make_legacy('custom-avra')
        result = self.run_nvim('nvim', theme='ayu-mirage')
        self.assertEqual(result['warnings'], [])
        for tool in ('btop', 'opencode'):
            self.assertTrue(result[tool])
            self.assertFalse((directory / (tool + '-sync.json')).exists())
            self.assertTrue(self.journal(tool).exists())
        self.assertEqual(self.run_nvim('nvim', 'reset')['warnings'], [])
        self.assert_restored()

    def test_missing_original_opencode_property_is_restored(self):
        self.original_opencode = '{\n  // no theme\n  "scroll_speed": 3\n}\n'
        self.opencode.write_text(self.original_opencode)
        self.make_legacy()
        self.assertEqual(self.run_nvim('nvim')['warnings'], [])
        self.assertEqual(self.run_nvim('nvim', 'reset')['warnings'], [])
        # Property removal preserves the original comments and other values.
        self.assertNotIn('"theme"', self.opencode.read_text())
        self.assertIn('// no theme', self.opencode.read_text())
        self.assertIn('"scroll_speed": 3', self.opencode.read_text())

    def test_edited_themes_remain_intact_during_migration(self):
        self.make_legacy()
        themes = {'btop': self.config / 'btop/themes/avra-nvim.theme',
                  'opencode': self.config / 'opencode/themes/avra-nvim.json'}
        for path in themes.values():
            path.write_text(path.read_text() + '\n# user edit\n')
        originals = {tool: path.read_text() for tool, path in themes.items()}
        result = self.run_nvim('nvim', theme='ayu-light')
        for tool, path in themes.items():
            self.assertFalse(result[tool])
            self.assertEqual(path.read_text(), originals[tool])
        self.assertEqual(len(result['warnings']), 2)
        self.assertTrue(all('edited' in warning for warning in result['warnings']))

    def test_conflicting_legacy_journals_do_not_overwrite_configs(self):
        first = self.make_legacy()
        second = self.state / 'another-app'
        second.mkdir()
        for tool in ('btop', 'opencode'):
            data = json.loads((first / (tool + '-sync.json')).read_text())
            data['original_theme'] = 'another-theme'
            (second / (tool + '-sync.json')).write_text(json.dumps(data))
        configs = self.btop.read_text(), self.opencode.read_text()
        result = self.run_nvim('nvim')
        self.assertFalse(result['btop'])
        self.assertFalse(result['opencode'])
        self.assertEqual(len(result['warnings']), 2)
        self.assertTrue(all('conflicting' in warning for warning in result['warnings']))
        self.assertEqual((self.btop.read_text(), self.opencode.read_text()), configs)
        for tool in ('btop', 'opencode'):
            self.assertFalse(self.journal(tool).exists())
            self.assertTrue((first / (tool + '-sync.json')).exists())

    def test_invalid_shared_state_is_not_replaced_by_legacy_state(self):
        directory = self.make_legacy()
        for tool in ('btop', 'opencode'):
            self.journal(tool).write_text('{invalid json')
        result = self.run_nvim('nvim')
        self.assertFalse(result['btop'])
        self.assertFalse(result['opencode'])
        self.assertEqual(len(result['warnings']), 2)
        self.assertTrue(all('invalid recovery' in warning for warning in result['warnings']))
        for tool in ('btop', 'opencode'):
            self.assertEqual(self.journal(tool).read_text(), '{invalid json')
            self.assertTrue((directory / (tool + '-sync.json')).exists())

    def test_legacy_state_for_other_configs_is_not_adopted(self):
        directory = self.make_legacy()
        for tool in ('btop', 'opencode'):
            path = directory / (tool + '-sync.json')
            data = json.loads(path.read_text())
            data['config_path'] = str(self.root / 'other-config')
            path.write_text(json.dumps(data))
        configs = self.btop.read_text(), self.opencode.read_text()
        result = self.run_nvim('nvim')
        self.assertFalse(result['btop'])
        self.assertFalse(result['opencode'])
        self.assertEqual(len(result['warnings']), 2)
        self.assertTrue(all('recovery state is missing' in warning for warning in result['warnings']))
        self.assertEqual((self.btop.read_text(), self.opencode.read_text()), configs)
        for tool in ('btop', 'opencode'):
            self.assertFalse(self.journal(tool).exists())

    def test_equivalent_legacy_records_can_migrate_on_disable(self):
        first = self.make_legacy()
        second = self.state / 'another-app'
        second.mkdir()
        for tool in ('btop', 'opencode'):
            data = json.loads((first / (tool + '-sync.json')).read_text())
            (second / (tool + '-sync.json')).write_text(json.dumps(data, sort_keys=True, indent=2))
        self.assertEqual(self.run_nvim('nvim', 'reset')['warnings'], [])
        self.assert_restored()
        for directory in (first, second):
            for tool in ('btop', 'opencode'):
                self.assertFalse((directory / (tool + '-sync.json')).exists())


if __name__ == '__main__':
    unittest.main()
