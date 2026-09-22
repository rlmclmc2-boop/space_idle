"""Source row, projection, and furnace validation; run through run.py."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from config_workbooks import read_changed_file
from import_workbook import validate_projection
import ui_text


class JewelFurnaceImportTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))

    def test_exact_source_and_display_registration(self):
        path = ROOT / 'config_excel/hightech.xlsx'
        row = read_changed_file(path, 'hightech', path.read_bytes())['宝石熔炼炉']
        self.assertEqual(self.data['hightech']['宝石熔炼炉'], row)
        validate_projection(self.data)
        contract = json.loads((ROOT / 'data/ui_text_contract.json').read_text(encoding='utf-8'))
        binding = contract['bindings']['hightech']['宝石熔炼炉']
        self.assertEqual(ui_text.t(binding['name']), '宝石熔炼炉')
        self.assertIn('不含自身', contract['entries'][binding['description']]['formulas'][1])

    def test_invalid_interval_rejected_for_both_furnaces(self):
        for name in ('超时空炼铁炉', '宝石熔炼炉'):
            data = copy.deepcopy(self.data)
            data['hightech'][name]['para1'] = 0
            with self.assertRaises(ValueError):
                validate_projection(data)

    def test_negative_multiplier_rejected(self):
        self.data['hightech']['宝石熔炼炉']['para2'] = -1
        with self.assertRaises(ValueError):
            validate_projection(self.data)


if __name__ == '__main__':
    unittest.main()
