"""Small self-check for bounded reads; does not run the game."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT / "tools" / "read_budget.py"


def run(*args, cwd=PROJECT):
    return subprocess.run([sys.executable, str(TOOL), *args], cwd=cwd,
                          capture_output=True, text=True, encoding="utf-8")


class ReadBudgetTest(unittest.TestCase):
    def test_role_route_and_project_relative_path(self):
        executor = run("route", "--role", "executor", "--task", "ui-text")
        self.assertEqual(executor.returncode, 0, executor.stderr)
        self.assertIn("ROLE FILE docs/roles/EXECUTOR.md", executor.stdout)
        self.assertIn("ROUTE docs/READ_ROUTE.md#ui-text", executor.stdout)
        self.assertNotIn("dot 审阅入口", executor.stdout)
        dot = run("route", "--role", "dot", "--task", "combat-local")
        self.assertEqual(dot.returncode, 0, dot.stderr)
        self.assertIn("ROLE FILE docs/roles/DOT.md", dot.stdout)
        located = run("grep", "--path", "docs/READ_ROUTE.md", "--query", "## ui-text", cwd=PROJECT.parent)
        self.assertEqual(located.returncode, 0, located.stderr)
        self.assertIn("MATCHES 1", located.stdout)

    def test_task_state_is_selected_by_id(self):
        folder = PROJECT / "docs" / "knowledge" / "tasks"
        chosen = folder / "test-read-budget.md"
        other = folder / "other-read-budget.md"
        chosen.write_text("chosen state\n", encoding="utf-8")
        other.write_text("other state\n", encoding="utf-8")
        try:
            result = run("route", "--role", "dot", "--task", "ui-text",
                         "--task-id", "test-read-budget")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("chosen state", result.stdout)
            self.assertNotIn("other state", result.stdout)
            self.assertNotIn("TASK INDEX", result.stdout)
        finally:
            chosen.unlink(missing_ok=True)
            other.unlink(missing_ok=True)

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

    def test_long_error_has_locator(self):
        missing = "x" * 700
        result = run("slice", "--path", missing, "--start", "1", "--chars", "400")
        self.assertEqual(result.returncode, 2)
        self.assertLessEqual(len(result.stderr), 400)
        match = re.search(r"details: (.+?); \d+ chars", result.stderr)
        self.assertIsNotNone(match)
        saved = Path(match.group(1))
        try:
            self.assertIn(missing, saved.read_text(encoding="utf-8"))
        finally:
            saved.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
