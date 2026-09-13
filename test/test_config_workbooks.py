"""Isolated integration tests for workbook synchronization and incremental imports."""
from pathlib import Path
import io
import json
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1] / "space-battleship"
sys.path.insert(0, str(ROOT / "tools"))
import config_workbooks as cw
import import_workbook as full


def edit_cell(path, sheet_name, coordinate, value=None, remove_cache=False):
    # Test fixture editing at the OOXML level preserves all other formula caches.
    original = path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(original)) as archive:
        name = dict(cw.sheet_parts(archive))[sheet_name]
        tree = cw.ET.fromstring(archive.read(name))
        cell = next(c for c in tree.iter(cw.Q + "c") if c.get("r") == coordinate)
        cached = cell.find(cw.Q + "v")
        if remove_cache:
            if cached is not None:
                cell.remove(cached)
        else:
            if cached is None:
                cached = cw.ET.SubElement(cell, cw.Q + "v")
            cached.text = str(value)
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
            for item in archive.infolist():
                target.writestr(item, cw.ET.tostring(tree) if item.filename == name else archive.read(item.filename))
    path.write_bytes(output.getvalue())


class IncrementalTests(unittest.TestCase):
    def setUp(self):
        area = Path(__file__).resolve().parent / "work"
        area.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=area)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "太空战舰.xlsx"
        shutil.copyfile(ROOT.parent / "太空战舰.xlsx", self.source)
        self.folder = self.root / "config_excel"
        self.target = self.root / "data/game_data.json"
        self.sync = cw.sync_workbooks(self.source, self.folder)

    def first_import(self):
        return cw.incremental_import(self.folder, self.target)

    def test_split_preserves_formulas_caches_styles_and_values(self):
        with zipfile.ZipFile(self.source) as master:
            names = [name for name, _ in cw.sheet_parts(master) if name != "总览"]
            self.assertEqual(set(names), set(self.sync["created"]))
            self.assertFalse((self.folder / "总览.xlsx").exists())
            for name in names:
                with zipfile.ZipFile(self.folder / (name + ".xlsx")) as output:
                    self.assertEqual([name], [n for n, _ in cw.sheet_parts(output)])
                    self.assertEqual(master.read(dict(cw.sheet_parts(master))[name]), output.read(dict(cw.sheet_parts(output))[name]))
                    self.assertEqual(master.read("xl/styles.xml"), output.read("xl/styles.xml"))
                    self.assertNotIn("xl/calcChain.xml", output.namelist())
        projected = full.full_import(self.source, self.root / "baseline.json")
        result = self.first_import()
        self.assertEqual(set(full.SECTIONS), set(result["parsed"]))
        actual = json.loads(self.target.read_text(encoding="utf-8"))
        for section in full.SECTIONS.values():
            self.assertEqual(projected[section], actual[section])

    def test_no_change_reads_no_workbook_and_writes_nothing(self):
        self.first_import()
        before = self.target.stat().st_mtime_ns
        state = self.target.with_name(".import_state.json").read_bytes()
        with patch.object(cw.openpyxl, "load_workbook", side_effect=AssertionError("Unchanged workbook parsed")):
            self.assertEqual([], self.first_import()["parsed"])
        self.assertEqual(before, self.target.stat().st_mtime_ns)
        self.assertEqual(state, self.target.with_name(".import_state.json").read_bytes())

    def test_only_changed_configuration_is_parsed(self):
        self.first_import()
        before = json.loads(self.target.read_text(encoding="utf-8"))
        edit_cell(self.folder / "config.xlsx", "config", "C6", 37)
        self.source.unlink()  # Incremental reading does not require/re-read master.
        with patch.object(cw, "read_changed_file", wraps=cw.read_changed_file) as reader:
            result = self.first_import()
            self.assertEqual(["config"], result["parsed"])
            self.assertEqual(1, reader.call_count)
        after = json.loads(self.target.read_text(encoding="utf-8"))
        self.assertEqual(37, after["config"]["movement"])
        for section in set(full.SECTIONS.values()) - {"config"}:
            self.assertEqual(before[section], after[section])

    def test_invalid_data_preserves_json_and_dirty_state(self):
        self.first_import()
        before = self.target.read_bytes()
        state_path = self.target.with_name(".import_state.json")
        state = state_path.read_bytes()
        edit_cell(self.folder / "config.xlsx", "config", "C6", -1)
        with self.assertRaises(ValueError):
            self.first_import()
        self.assertEqual(before, self.target.read_bytes())
        self.assertEqual(state, state_path.read_bytes())
        edit_cell(self.folder / "config.xlsx", "config", "C6", 39)
        self.assertEqual(["config"], self.first_import()["parsed"])

    def test_missing_formula_cache_rejects_entire_batch(self):
        self.first_import()
        before = self.target.read_bytes()
        edit_cell(self.folder / "config.xlsx", "config", "C6", 39)
        edit_cell(self.folder / "equipment.xlsx", "equipment", "C5", remove_cache=True)
        with self.assertRaisesRegex(ValueError, "公式缺少计算缓存"):
            self.first_import()
        self.assertEqual(before, self.target.read_bytes())

    def test_missing_required_file_is_not_silently_ignored(self):
        self.first_import()
        before = self.target.read_bytes()
        (self.folder / "mon.xlsx").unlink()
        with self.assertRaisesRegex(ValueError, "缺少 mon.xlsx"):
            self.first_import()
        self.assertEqual(before, self.target.read_bytes())

    def test_sync_updates_existing_and_keeps_unchanged_files(self):
        before = {p.name:p.stat().st_mtime_ns for p in self.folder.glob("*.xlsx")}
        result = cw.sync_workbooks(self.source, self.folder)
        self.assertEqual([], result["created"] + result["updated"])
        edit_cell(self.source, "config", "C6", 45)
        result = cw.sync_workbooks(self.source, self.folder)
        self.assertEqual(["config"], result["updated"])
        self.assertEqual([], result["created"])
        for path in self.folder.glob("*.xlsx"):
            if path.name != "config.xlsx":
                self.assertEqual(before[path.name], path.stat().st_mtime_ns)
        (self.folder / "notes.txt").write_text("unrelated")
        edit_cell(self.folder / "config.xlsx", "config", "C6", 88)
        self.assertEqual(["config"], cw.sync_workbooks(self.source, self.folder)["updated"])
        self.assertTrue((self.folder / "notes.txt").exists())

    def test_atomic_commit_rolls_back_on_replace_failure(self):
        first, second = self.root / "one.json", self.root / "two.json"
        first.write_bytes(b"old-one")
        second.write_bytes(b"old-two")
        replace = cw.os.replace
        def fail_second(source, target):
            if target == second:
                raise PermissionError("Locked fixture")
            return replace(source, target)
        with patch.object(cw.os, "replace", side_effect=fail_second):
            with self.assertRaises(PermissionError):
                cw.atomic_batch({first:b"new-one", second:b"new-two"})
        self.assertEqual(b"old-one", first.read_bytes())
        self.assertEqual(b"old-two", second.read_bytes())


if __name__ == "__main__":
    unittest.main(verbosity=2)
