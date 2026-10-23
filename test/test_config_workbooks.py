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
from current_workbook_fixture import build_current_master

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
        if isinstance(value,str):
            for child in list(cell):cell.remove(child)
            cell.set('t','inlineStr')
            cw.ET.SubElement(cw.ET.SubElement(cell,cw.Q+'is'),cw.Q+'t').text=value
        elif remove_cache:
            if cached is not None:
                if cell.find(cw.Q + "f") is None:
                    formula = cw.ET.SubElement(cell, cw.Q + "f")
                    formula.text = cached.text
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
        build_current_master(ROOT, self.source, full.SECTIONS)
        self.folder = self.root / "config_excel"
        self.target = self.root / "data/game_data.json"
        shutil.copytree(ROOT/'data',self.target.parent)
        self.folder.mkdir()
        for name in ('hyperspace_config.xlsx','hyperspace_enemies.xlsx'):
            shutil.copy2(ROOT/'config_excel'/name,self.folder/name)
        self.sync = cw.sync_workbooks(self.source, self.folder)

    def first_import(self):
        for name in ('hyperspace_config.xlsx','hyperspace_enemies.xlsx'):
            if not (self.folder/name).exists():
                shutil.copy2(ROOT/'config_excel'/name,self.folder/name)
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
        baseline=self.root/'baseline';baseline.mkdir()
        for name in ('data','config_excel'):shutil.copytree(self.root/name,baseline/name)
        projected = full.full_import(self.source, baseline/'data/game_data.json')
        prior_entities = {p.stem: p.read_bytes() for p in self.target.parent.glob("*.json") if p.name != "game_data.json"}
        result = self.first_import()
        changed_entities = {p.stem for p in self.target.parent.glob("*.json") if p.name not in ("game_data.json", ".import_state.json") and prior_entities.get(p.stem) != p.read_bytes()}
        self.assertEqual((set(full.SECTIONS) & set(names)) | changed_entities, set(result["parsed"]))
        actual = json.loads(self.target.read_text(encoding="utf-8"))
        for section in full.SECTIONS.values():
            self.assertEqual(projected.get(section), actual.get(section))

    def test_no_change_preserves_publication_and_mtimes(self):
        self.first_import()
        before = self.target.stat().st_mtime_ns
        state = self.target.with_name(".import_state.json").read_bytes()
        self.assertEqual([], self.first_import()["parsed"])
        self.assertEqual(before, self.target.stat().st_mtime_ns)
        self.assertEqual(state, self.target.with_name(".import_state.json").read_bytes())

    def test_only_changed_configuration_is_parsed(self):
        self.first_import()
        before = json.loads(self.target.read_text(encoding="utf-8"))
        edit_cell(self.folder / "config.xlsx", "config", "C6", 37)
        self.source.unlink()  # Incremental reading does not require/re-read master.
        result = self.first_import()
        self.assertEqual(["config"], result["parsed"])
        after = json.loads(self.target.read_text(encoding="utf-8"))
        self.assertEqual(37, after["config"]["movement"])
        for section in set(full.SECTIONS.values()) - {"config"}:
            self.assertEqual(before.get(section), after.get(section))

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
        edit_cell(self.folder / "equipment.xlsx", "equipment", "E4", remove_cache=True)
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

    def test_hightech_only_change_preserves_other_sections(self):
        self.first_import()
        before = json.loads(self.target.read_text(encoding="utf-8"))
        edit_cell(self.folder / "hightech.xlsx", "hightech", "D4", 90)
        result = self.first_import()
        self.assertEqual(["hightech"], result["parsed"])
        after = json.loads(self.target.read_text(encoding="utf-8"))
        self.assertEqual(90, after["hightech"]["超时空炼铁炉"]["tpCostBase"])
        self.assertEqual(before["hightech"]["超时空炼铁炉"]["des"], after["hightech"]["超时空炼铁炉"]["des"])
        for section in full.SECTIONS.values():
            if section != "hightech": self.assertEqual(before.get(section), after.get(section))

    def test_hightech_invalid_interval_preserves_projection(self):
        self.first_import()
        before = self.target.read_bytes()
        state = self.target.with_name(".import_state.json").read_bytes()
        edit_cell(self.folder / "hightech.xlsx", "hightech", "G4", 0)
        with self.assertRaisesRegex(ValueError, "interval"):
            self.first_import()
        self.assertEqual(before, self.target.read_bytes())
        self.assertEqual(state, self.target.with_name(".import_state.json").read_bytes())

    def test_hightech_limit_and_offline_max_validation(self):
        self.first_import()
        before = self.target.read_bytes()
        for coordinate, value in [("C12", 0), ("C12", -1), ("C9", -1)]:
            cw.sync_workbooks(self.source, self.folder)
            edit_cell(self.folder / "config.xlsx", "config", coordinate, value)
            with self.assertRaises(ValueError): self.first_import()
            self.assertEqual(before, self.target.read_bytes())
        cw.sync_workbooks(self.source, self.folder)
        edit_cell(self.folder / "config.xlsx", "config", "C9", 0)
        self.first_import()
        self.assertEqual(0, json.loads(self.target.read_text(encoding="utf-8"))["config"]["offlineMax"])

    def test_hightech_duplicate_name_rejected(self):
        row = {"name":"same"}
        with self.assertRaises(ValueError): full.convert_sheet("hightech", [row, row])

    def test_description_expression_validation(self):
        row={"name":"test","para1":0.08,"description":"每para1秒 {过去一分钟的铁生成量*para1*等级,向上取整}"}
        full.validate_description(row)
        full.validate_description({**row,"description":"{（1+para1）^等级,百分比显示,保留两位小数,即100.3%展示为100%}"})
        for invalid in [None,"","{para1*等级","{unknown*2}","{load(1)}","{1,未知规则}","para9"]:
            with self.subTest(description=invalid):
                with self.assertRaises(ValueError): full.validate_description({**row,"description":invalid})

    def test_invalid_description_keeps_existing_projection(self):
        self.first_import()
        before=self.target.read_bytes()
        state=self.target.with_name(".import_state.json").read_bytes()
        edit_cell(self.folder / "hightech.xlsx", "hightech", "D4", 90)
        import openpyxl
        book=openpyxl.load_workbook(self.folder/'hightech.xlsx',read_only=True)
        column=next(i for i,c in enumerate(book['hightech'][1],1) if c.value=='description');book.close()
        edit_cell(self.folder/'hightech.xlsx','hightech',openpyxl.utils.get_column_letter(column)+'4','{unrecognized(1)}')
        with self.assertRaises(ValueError): self.first_import()
        self.assertEqual(before,self.target.read_bytes())
        self.assertEqual(state,self.target.with_name(".import_state.json").read_bytes())

    def test_atomic_commit_rolls_back_on_replace_failure(self):
        first, second = self.root / "one.json", self.root / "two.json"
        first.write_bytes(b"old-one")
        second.write_bytes(b"old-two")
        replace = cw.os.replace
        fired=False
        def fail_second(source, target):
            nonlocal fired
            if target == second and not fired:
                fired=True
                raise PermissionError("Locked fixture")
            return replace(source, target)
        with patch.object(cw.os, "replace", side_effect=fail_second):
            with self.assertRaises(PermissionError):
                cw.atomic_batch({first:b"new-one", second:b"new-two"})
        self.assertEqual(b"old-one", first.read_bytes())
        self.assertEqual(b"old-two", second.read_bytes())


if __name__ == "__main__":
    unittest.main(verbosity=2)
