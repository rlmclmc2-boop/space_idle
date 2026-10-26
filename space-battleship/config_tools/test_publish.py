"""Black-box publication probes against copies of the real consumer workbooks."""

from __future__ import annotations

import json
import re
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

import openpyxl

from compile import (DEFAULT_MANIFEST, ROOT, HYPERSPACE_NONNEGATIVE_KEYS,
                     HYPERSPACE_POSITIVE_KEYS, HYPERSPACE_PROBABILITY_KEYS,
                      compile_config, quantized_range_issue)


class PublicationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.baseline_temporary = tempfile.TemporaryDirectory(prefix="space-config-baseline-")
        cls.baseline_root = Path(cls.baseline_temporary.name)
        cls.baseline_source = cls.baseline_root / "input"
        shutil.copytree(ROOT / "config_excel", cls.baseline_source, ignore=shutil.ignore_patterns("published"))
        manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))
        manifest["kind"] = "test"
        cls.manifest = cls.baseline_root / "test_manifest.json"
        cls.manifest.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        baseline_output = cls.baseline_root / "active.json"
        result = compile_config(cls.manifest, baseline_output, source=cls.baseline_source)
        if not result["ok"]: raise AssertionError(result["errors"][:3])
        cls.baseline_result = result
        cls.original = baseline_output.read_bytes()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.baseline_temporary.cleanup()

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="space-config-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "input"
        shutil.copytree(self.baseline_source, self.source)
        self.output = self.root / "active.json"
        self.report = self.root / "validation.json"
        self.output.write_bytes(self.original)

    def change(self, file: str, sheet: str, coordinate: str, value: object) -> None:
        path = self.source / file
        workbook = openpyxl.load_workbook(path)
        workbook[sheet][coordinate] = value
        workbook.save(path)
        workbook.close()

    def change_field(self, file: str, sheet: str, field: str, row: int, value: object) -> None:
        path = self.source / file
        workbook = openpyxl.load_workbook(path)
        worksheet = workbook[sheet]
        column = next(i for i, cell in enumerate(worksheet[1], 1) if cell.value == field)
        worksheet.cell(row, column).value = value
        workbook.save(path)
        workbook.close()

    def change_hyperspace_parameters(self, values: dict[str, object], field: str = "value") -> None:
        path = self.source / "hyperspace_config.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["基础参数"]
        columns = {cell.value: index for index, cell in enumerate(sheet[1], 1)}
        found = set()
        for row in range(4, sheet.max_row + 1):
            key = sheet.cell(row, columns["key"]).value
            if key in values:
                sheet.cell(row, columns[field]).value = values[key]
                found.add(key)
        self.assertEqual(found, set(values))
        workbook.save(path)
        workbook.close()

    def reject_hyperspace_parameters(self, expected: dict[str, str]) -> None:
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertFalse(result["ok"])
        actual = {(error["key"], error["code"]) for error in result["errors"]
                  if error["workbook"] == "hyperspace_config.xlsx" and error["sheet"] == "基础参数"}
        for key, code in expected.items():
            self.assertIn((key, code), actual)
        self.assertEqual(self.output.read_bytes(), self.original)
        self.assertEqual(json.loads(self.report.read_text(encoding="utf-8")), result)

    def reject(self, expected: str) -> None:
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertFalse(result["ok"])
        self.assertIn(expected, {error["code"] for error in result["errors"]})
        self.assertEqual(self.output.read_bytes(), self.original, "failed candidate replaced active config")
        self.assertEqual(json.loads(self.report.read_text(encoding="utf-8")), result)
        self.assertTrue(all({"workbook", "sheet", "row", "column", "key", "code", "detail"} <= error.keys()
                            for error in result["errors"]))

    def test_duplicate_key_rejected_without_replacing_active(self) -> None:
        workbook = openpyxl.load_workbook(self.source / "equipment.xlsx")
        sheet = workbook["equipment"]
        primary_column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "name")
        sheet.cell(5, primary_column).value = sheet.cell(4, primary_column).value
        workbook.save(self.source / "equipment.xlsx")
        workbook.close()
        self.reject("DuplicatePrimaryKey")

    def test_missing_foreign_key_rejected(self) -> None:
        workbook = openpyxl.load_workbook(self.source / "hyperspace_enemies.xlsx")
        sheet = workbook["编队槽位"]
        column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "enemy_id")
        sheet.cell(4, column).value = 99999999
        workbook.save(self.source / "hyperspace_enemies.xlsx")
        workbook.close()
        self.reject("MissingReference")

    def test_formula_without_cache_rejected(self) -> None:
        self.change("level.xlsx", "level", "A4", "=2+2")
        self.reject("FormulaCacheMissing")

    def test_out_of_bounds_formation_rejected(self) -> None:
        workbook = openpyxl.load_workbook(self.source / "hyperspace_enemies.xlsx")
        sheet = workbook["编队槽位"]
        column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "x")
        sheet.cell(4, column).value = 900
        workbook.save(self.source / "hyperspace_enemies.xlsx")
        workbook.close()
        self.reject("FormationBounds")

    def test_route_gap_rejected(self) -> None:
        workbook = openpyxl.load_workbook(self.source / "hyperspace_enemies.xlsx")
        sheet = workbook["路线编排"]
        column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "order")
        sheet.cell(4, column).value = 44
        workbook.save(self.source / "hyperspace_enemies.xlsx")
        workbook.close()
        self.reject("RouteOrder")

    def test_unknown_typed_rule_rejected(self) -> None:
        workbook = openpyxl.load_workbook(self.source / "hyperspace_config.xlsx")
        sheet = workbook["基础参数"]
        column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "key")
        sheet.cell(4, column).value = "unregistered_rule"
        workbook.save(self.source / "hyperspace_config.xlsx")
        workbook.close()
        self.reject("UnknownRuleKey")

    def test_hyperspace_zero_reward_level_step_rejected(self) -> None:
        self.change_field("hyperspace_config.xlsx", "基础参数", "value", 27, 0)
        self.reject("HyperspacePositiveParameter")

    def test_hyperspace_zero_value_precision_rejected(self) -> None:
        self.change_field("hyperspace_config.xlsx", "基础参数", "value", 23, 0)
        self.reject("HyperspacePositiveParameter")

    def test_hyperspace_probability_over_one_rejected(self) -> None:
        self.change_field("hyperspace_config.xlsx", "基础参数", "value", 43, 1.5)
        self.reject("HyperspaceProbabilityRange")

    def test_every_positive_hyperspace_parameter_rejected_at_zero(self) -> None:
        fixed = {"overflow_capacity", "completion_budget", "maximum_filter_conditions",
                 "maximum_filter_string_length", "maximum_forecast_attempts"}
        keys = HYPERSPACE_POSITIVE_KEYS - fixed
        self.change_hyperspace_parameters({key: 0 for key in keys})
        self.reject_hyperspace_parameters({key: "HyperspacePositiveParameter" for key in keys})

    def test_every_probability_and_nonnegative_parameter_rejected(self) -> None:
        changes = {key: 1.5 for key in HYPERSPACE_PROBABILITY_KEYS}
        changes.update({key: -1 for key in HYPERSPACE_NONNEGATIVE_KEYS})
        self.change_hyperspace_parameters(changes)
        expected = {key: "HyperspaceProbabilityRange" for key in HYPERSPACE_PROBABILITY_KEYS}
        expected.update({key: "HyperspaceNonnegativeParameter" for key in HYPERSPACE_NONNEGATIVE_KEYS})
        self.reject_hyperspace_parameters(expected)

    def test_hyperspace_cross_field_and_magnitude_rejected(self) -> None:
        changes = {"maximum_equipped": 1, "ticket": 300000, "initial_retention_capacity": 201,
                   "retention_capacity_gain": 11, "unlock_stage": 221,
                   "amplification_rate": -1, "modernization_base_coefficient": 9e15}
        self.change_hyperspace_parameters(changes)
        self.reject_hyperspace_parameters({
            "maximum_legendary": "HyperspaceCapacityRelation", "ticket": "HyperspaceCapacityRelation",
            "initial_retention_capacity": "HyperspaceCapacityRelation",
            "retention_capacity_gain": "HyperspaceCapacityRelation", "unlock_stage": "MissingReference",
            "amplification_rate": "HyperspaceAmplificationRange",
            "modernization_base_coefficient": "HyperspaceParameterMagnitude"})

    def test_hyperspace_declared_type_is_fixed(self) -> None:
        self.change_hyperspace_parameters({"modernization_level_step": "float"}, field="data_type")
        self.reject_hyperspace_parameters({"modernization_level_step": "HyperspaceParameterType"})

    def test_hyperspace_runtime_divisors_and_probabilities_rejected_together(self) -> None:
        self.change_hyperspace_parameters({
            "late_supply_ramp_seconds": 0, "modernization_level_step": 0,
            "modernization_cost_base": 0, "affix_initial_probability": 1.5,
            "hanging_initial_probability": -0.1,
        })
        self.reject_hyperspace_parameters({
            "late_supply_ramp_seconds": "HyperspacePositiveParameter",
            "modernization_level_step": "HyperspacePositiveParameter",
            "modernization_cost_base": "HyperspacePositiveParameter",
            "affix_initial_probability": "HyperspaceProbabilityRange",
            "hanging_initial_probability": "HyperspaceProbabilityRange",
        })

    def test_missing_hyperspace_parameter_rejected(self) -> None:
        path = self.source / "hyperspace_config.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["基础参数"]
        sheet.delete_rows(40)
        workbook.save(path)
        workbook.close()
        self.reject("MissingHyperspaceParameter")

    def test_stage_point_order_and_bounds_rejected(self) -> None:
        # Preserve existing formula caches while changing the literal C4 cell.
        path = self.source / "level.xlsx"
        replacement = path.with_suffix(".patched")
        old = b"{33001|0.140000,33002|0.325000,33003|0.510000,33004|0.695000,33005|0.880000}"
        with zipfile.ZipFile(path) as original, zipfile.ZipFile(replacement, "w") as changed:
            for member in original.infolist():
                data = original.read(member.filename)
                if member.filename == "xl/worksheets/sheet1.xml":
                    self.assertIn(old, data)
                    data = data.replace(old, b"{33001|1.2}", 1)
                changed.writestr(member, data)
        replacement.replace(path)
        self.reject("StagePointOrder")

    def test_negative_formula_result_rejected(self) -> None:
        path = self.source / "level.xlsx"
        replacement = path.with_suffix(".patched")
        with zipfile.ZipFile(path) as original, zipfile.ZipFile(replacement, "w") as changed:
            for member in original.infolist():
                data = original.read(member.filename)
                if member.filename == "xl/worksheets/sheet1.xml":
                    data, count = re.subn(rb'(<ns0:c r="D64"[^>]*><ns0:f>[^<]+</ns0:f><ns0:v>)[^<]+', rb'\g<1>-1', data, count=1)
                    self.assertEqual(count, 1)
                changed.writestr(member, data)
        replacement.replace(path)
        self.reject("StageRatioRange")

    def test_probability_rejected(self) -> None:
        self.change_field("hyperspace_enemies.xlsx", "早段回退预算", "chance", 4, 1.5)
        self.reject("ProbabilityRange")

    def test_embedded_enemy_drop_probability_rejected(self) -> None:
        self.change_field("mon.xlsx", "mon", "res", 4, "{1,10,1.2}")
        self.reject("EmbeddedDropRange")

    def test_empty_required_cell_rejected(self) -> None:
        self.change_field("equipment.xlsx", "equipment", "name", 4, None)
        self.reject("RequiredValueMissing")

    def test_numeric_string_rejected(self) -> None:
        self.change_field("equipment.xlsx", "equipment", "cd", 4, "3")
        self.reject("InvalidFieldType")

    def test_unlisted_sheet_rejected(self) -> None:
        path = self.source / "equipment.xlsx"
        workbook = openpyxl.load_workbook(path)
        workbook.create_sheet("unlisted")
        workbook.save(path)
        workbook.close()
        self.reject("SheetSetMismatch")

    def test_technology_dependency_cycle_rejected(self) -> None:
        self.change_field("ai_tech_tree.xlsx", "ai_tech_tree", "requirements", 4, "singularity:1")
        self.reject("DependencyCycle")

    def test_planet_building_dependency_cycle_rejected(self) -> None:
        self.change_field("planet_build.xlsx", "planet_build", "previous_id", 4, "station")
        self.reject("DependencyCycle")

    def test_duplicate_formation_slot_rejected(self) -> None:
        self.change_field("hyperspace_enemies.xlsx", "编队槽位", "slot_index", 5, 0)
        self.reject("DuplicatePrimaryKey")

    def test_formation_overlap_rejected(self) -> None:
        path = self.source / "hyperspace_enemies.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["编队槽位"]
        header = {cell.value: i for i, cell in enumerate(sheet[1], 1)}
        for field in ("x", "y"):
            sheet.cell(5, header[field]).value = sheet.cell(4, header[field]).value
        workbook.save(path)
        workbook.close()
        self.reject("FormationOverlap")

    def test_repeated_route_group_rejected(self) -> None:
        path = self.source / "hyperspace_enemies.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["路线编排"]
        column = next(i for i, cell in enumerate(sheet[1], 1) if cell.value == "group_id")
        sheet.cell(5, column).value = sheet.cell(4, column).value
        workbook.save(path)
        workbook.close()
        self.reject("RepeatedRouteGroup")

    def test_missing_route_coverage_rejected(self) -> None:
        path = self.source / "hyperspace_enemies.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["路线编排"]
        sheet.delete_rows(4)
        workbook.save(path)
        workbook.close()
        self.reject("RouteCoverage")

    def test_missing_budget_member_rejected(self) -> None:
        path = self.source / "hyperspace_enemies.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["早段回退预算"]
        header = {cell.value: i for i, cell in enumerate(sheet[1], 1)}
        reference = sheet.cell(4, header["reference_id"]).value
        ordinal = sheet.cell(4, header["reference_member_ordinal"]).value
        for row in range(sheet.max_row, 3, -1):
            if sheet.cell(row, header["reference_id"]).value == reference and sheet.cell(row, header["reference_member_ordinal"]).value == ordinal:
                sheet.delete_rows(row)
        workbook.save(path)
        workbook.close()
        self.reject("BudgetCoverage")

    def test_duplicate_budget_block_rejected(self) -> None:
        path = self.source / "hyperspace_enemies.xlsx"
        workbook = openpyxl.load_workbook(path)
        sheet = workbook["早段回退预算"]
        header = {cell.value: i for i, cell in enumerate(sheet[1], 1)}
        for field in ("reference_id", "reference_member_ordinal", "drop_order"):
            sheet.cell(5, header[field]).value = sheet.cell(4, header[field]).value
        workbook.save(path)
        workbook.close()
        self.reject("DuplicatePrimaryKey")

    def test_zero_budget_row_is_not_compressed(self) -> None:
        self.change_field("hyperspace_enemies.xlsx", "早段回退预算", "amount", 4, 0)
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertTrue(result["ok"], result["errors"][:3])
        rows = json.loads(self.output.read_text(encoding="utf-8"))["hyperspace_enemies"]["早段回退预算"]
        self.assertEqual(rows[0]["amount"], 0)
        self.assertEqual(len(rows), len(json.loads(self.original)["hyperspace_enemies"]["早段回退预算"]))

    def test_reversed_affix_range_rejected(self) -> None:
        self.change_field("hyperspace_config.xlsx", "词缀区间", "minimum", 4, 9)
        self.reject("RangeReversed")

    def test_fixed_compatibility_rule_rejected(self) -> None:
        self.change_field("hyperspace_config.xlsx", "固定规则_兼容说明", "value", 4, 12345)
        self.reject("FixedRuleChanged")

    def test_quantized_affix_range_must_contain_a_lattice_value(self) -> None:
        self.change_hyperspace_parameters({"value_precision": 1})
        self.reject("QuantizedRangeEmpty")

    def test_quantized_legendary_range_must_contain_a_lattice_value(self) -> None:
        self.change_hyperspace_parameters({"value_precision": 1})
        self.change_field("hyperspace_config.xlsx", "传说随机参数", "minimum", 4, 0.1)
        self.change_field("hyperspace_config.xlsx", "传说随机参数", "maximum", 4, 0.2)
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertFalse(result["ok"])
        self.assertIn(("传说随机参数", "QuantizedRangeEmpty"),
                      {(error["sheet"], error["code"]) for error in result["errors"]})
        self.assertEqual(self.output.read_bytes(), self.original)

    def test_fixed_hyperspace_values_share_runtime_contract(self) -> None:
        from compile import HYPERSPACE_CONTRACT
        for key, fixed in HYPERSPACE_CONTRACT["fixedValues"].items():
            with self.subTest(key=key):
                self.change_hyperspace_parameters({key: fixed + 1})
                self.reject_hyperspace_parameters({key: "FixedRuleChanged"})
                self.change_hyperspace_parameters({key: fixed})

    def test_quantized_sampling_indices_fit_signed_32_bit_bounds(self) -> None:
        self.assertIsNone(quantized_range_issue(-2147483648, 2147483647, 1))
        self.assertEqual(quantized_range_issue(-2147483649, 0, 1), "QuantizedIndexOutOfRange")
        self.assertEqual(quantized_range_issue(0, 2147483648, 1), "QuantizedIndexOutOfRange")
        self.assertEqual(quantized_range_issue(1.8, 2, 1e-10), "QuantizedIndexOutOfRange")

    def test_unrepresentable_affix_index_rejects_publication(self) -> None:
        self.change_hyperspace_parameters({"value_precision": 1e-10})
        self.change_field("hyperspace_config.xlsx", "词缀区间", "minimum", 4, 1.8)
        self.change_field("hyperspace_config.xlsx", "词缀区间", "maximum", 4, 2)
        self.reject("QuantizedIndexOutOfRange")

    def test_final_representable_affix_index_publishes(self) -> None:
        self.change_field("hyperspace_config.xlsx", "词缀区间", "minimum", 4, 2147483.6469)
        self.change_field("hyperspace_config.xlsx", "词缀区间", "maximum", 4, 2147483.6470001)
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertTrue(result["ok"], result["errors"][:3])

    def test_independent_test_manifest_uses_same_compiler(self) -> None:
        manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))
        manifest["kind"] = "test"
        path = self.root / "test_manifest.json"
        path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        result = compile_config(path, self.output, self.report, self.source)
        self.assertTrue(result["ok"], result["errors"][:3])
        self.assertEqual(self.output.read_bytes(), self.original)

    def test_real_content_coverage_is_stable(self) -> None:
        manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["workbooks"]), 29)
        self.assertEqual(sum(len(book["sheets"]) for book in manifest["workbooks"]), 49)
        payload = json.loads(self.original)
        self.assertEqual(len(payload["level"]["level"]), 220)
        self.assertEqual(len(payload["hyperspace_enemies"]["路线编排"]), 40)
        self.assertTrue(self.baseline_result["semanticHash"])

    def test_published_copy_cannot_override_root_workbook(self) -> None:
        published = self.source / "published"
        published.mkdir()
        shutil.copy2(self.source / "equipment.xlsx", published / "equipment.xlsx")
        workbook = openpyxl.load_workbook(published / "equipment.xlsx")
        workbook["equipment"]["A4"] = "invalid published copy"
        workbook.save(published / "equipment.xlsx")
        workbook.close()
        result = compile_config(self.manifest, self.output, self.report, self.source)
        self.assertTrue(result["ok"], result["errors"][:3])
        self.assertEqual(result["sourceHash"], self.baseline_result["sourceHash"])
        self.assertEqual(self.output.read_bytes(), self.original)

    def test_test_manifest_cannot_point_at_production_input(self) -> None:
        manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))
        manifest["kind"] = "test"
        path = self.root / "test_manifest.json"
        path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
        result = compile_config(path, self.output, self.report, source=ROOT / "config_excel")
        self.assertEqual(result["errors"][0]["code"], "TestManifestUsesProductionInput")
        self.assertEqual(json.loads(self.report.read_text(encoding="utf-8")), result)
        self.assertEqual(self.output.read_bytes(), self.original)

    def test_production_manifest_cannot_point_at_test_input(self) -> None:
        result = compile_config(DEFAULT_MANIFEST, self.output, self.report, source=self.source)
        self.assertEqual(result["errors"][0]["code"], "ProductionManifestUsesTestInput")
        self.assertEqual(json.loads(self.report.read_text(encoding="utf-8")), result)
        self.assertEqual(self.output.read_bytes(), self.original)


if __name__ == "__main__":
    unittest.main()
