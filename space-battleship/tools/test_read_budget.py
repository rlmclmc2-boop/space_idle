"""Small self-check for bounded reads; does not run the game."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT / "tools" / "read_budget.py"


def run(*args):
    return subprocess.run([sys.executable, str(TOOL), *args], cwd=PROJECT,
                          capture_output=True, text=True, encoding="utf-8")


class ReadBudgetTest(unittest.TestCase):
    def test_json_target_and_root_guard(self):
        item = run("json", "--path", "data/ui_text_contract.json",
                   "--key", "entries/battle.finale_cleared")
        self.assertEqual(item.returncode, 0, item.stderr)
        self.assertIn('"params": []', item.stdout)
        root = run("json", "--path", "data/game_data.json")
        self.assertEqual(root.returncode, 2)
        self.assertIn("--key or --where required", root.stderr)

    def test_excel_target(self):
        result = run("xlsx", "--path", "config_excel/equipment.xlsx", "--sheet",
                     "equipment", "--find", "armour", "--columns", "1", "3", "4")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCHES 1", result.stdout)
        self.assertIn("1:armour", result.stdout)

    def test_overflow_is_resumable(self):
        result = run("grep", "--path", "scripts/game.gd", "--query", "func ",
                     "--chars", "400")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("OVER LIMIT", result.stdout)
        match = re.search(r"saved: (.+)", result.stdout)
        self.assertIsNotNone(match)
        saved = Path(match.group(1))
        try:
            self.assertIn("MATCHES", saved.read_text(encoding="utf-8"))
            continued = run("slice", "--path", str(saved), "--start", "1", "--count", "2")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("MATCHES", continued.stdout)
        finally:
            saved.unlink(missing_ok=True)

    def test_error_log_keeps_location(self):
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as out:
            out.write("setup\nERROR failed\ncaused by fixture\n")
        path = Path(out.name)
        try:
            result = run("log", "--path", str(path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("2: ERROR failed", result.stdout)
            self.assertIn("3: caused by fixture", result.stdout)
        finally:
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
