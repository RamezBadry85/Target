"""Launcher regression: never remove the real launcher to test this check."""
import runpy
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class LauncherChecks(unittest.TestCase):
    def test_existing_launcher_passes(self):
        runpy.run_path(str(ROOT / 'tool/verify_scaffold.py'))

    def test_missing_launcher_fails(self):
        original = Path.is_file

        def is_file(path):
            if path.name == 'MainActivity.kt':
                return False
            return original(path)

        with patch.object(Path, 'is_file', is_file):
            with self.assertRaisesRegex(AssertionError, 'Missing Android launcher'):
                runpy.run_path(str(ROOT / 'tool/verify_scaffold.py'))


if __name__ == '__main__':
    unittest.main()
