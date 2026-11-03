"""Static guards supplement native unit tests; these are NOT dialog runtime tests."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'third_party/file_saver'


class NativeSaverContract(unittest.TestCase):
    def test_macos_cancel_completes_and_errors_are_typed(self):
        source = (ROOT / 'macos/Classes/Dialog.swift').read_text()
        self.assertIn('result(nil)', source)
        self.assertIn('FlutterError(code: "FILE_WRITE_ERROR"', source)
        self.assertNotIn('result("Failed to save file")', source)

    def test_android_returns_uri_without_swallowing_write_errors(self):
        source = (ROOT / 'android/src/main/kotlin/com/incrediblezayed/file_saver/Dialog.kt').read_text()
        self.assertIn('writeDocument(', source)
        self.assertIn('result?.success(uri.toString())', source)
        self.assertNotIn('fileUtils.getPath', source)
        self.assertNotIn('private fun saveFile', source)

    def test_windows_dialog_and_filter_use_wide_api(self):
        source = (ROOT / 'windows/file_saver_plugin.cpp').read_text()
        self.assertNotIn('bæegin', source)
        self.assertIn('GetSaveFileNameW', source)
        self.assertIn('CommDlgExtendedError()', source)
        self.assertIn('if (!WriteDocument(', source)


if __name__ == '__main__':
    unittest.main()
