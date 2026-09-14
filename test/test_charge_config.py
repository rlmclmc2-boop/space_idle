"""Charge projection and incremental-import regression, run via test/run.py."""
from pathlib import Path
import copy
import json
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
import config_workbooks as cw
import import_workbook as iw
from level_editor_store import Store


class ChargeConfigTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))

    def test_source_and_projection(self):
        path = ROOT / 'config_excel/charge.xlsx'
        rows = cw.read_changed_file(path, 'charge', path.read_bytes())
        self.assertEqual(rows, self.data['charge'])
        self.assertEqual(len(rows), 3)
        iw.validate_projection(self.data)

    def test_invalid_values_rejected(self):
        for field, value in [('para_1', 999), ('para_2', 0), ('para_3', -1),
                             ('para_7', -0.1), ('para_7', None), ('para_7', float('inf')),
                             ('para_4', 0), ('para_5', 0.49), ('para_6', 0.9),
                             ('unlock', 999), ('func', ''),
                             ('des', '{load(1)}'), ('des', '{para9}'),
                             ('des', '{1,unknown}')]:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.data)
                data['charge']['攻击充能'][field] = value
                with self.assertRaises(ValueError):
                    iw.validate_projection(data)

    def test_duplicate_and_unknown_effect_rejected(self):
        row = self.data['charge']['攻击充能']
        with self.assertRaises(ValueError):
            iw.convert_sheet('charge', [row, row])
        self.data['charge']['未实现效果'] = row
        with self.assertRaises(ValueError):
            iw.validate_projection(self.data)

    def test_fractional_charge_count_parameters(self):
        self.data['charge']['攻击充能'].update(para_5=0.5,para_6=1.5)
        iw.validate_projection(self.data)

    def test_level_editor_preserves_charge(self):
        store = Store(ROOT)
        self.assertIn('charge', store.paths)
        request = store.load()
        result = store.execute(request, False)
        self.assertIn('校验通过',result['message'])
        self.assertEqual(json.loads(store.target.read_text(encoding='utf-8'))['charge'], self.data['charge'])

    def test_incremental_import_and_failure_preserves_projection(self):
        directory = ROOT / 'config_excel'
        target = ROOT / 'data/game_data.json'
        first = cw.incremental_import(directory, target)
        self.assertIn('charge', first['parsed'])
        self.assertEqual(json.loads(target.read_text(encoding='utf-8'))['charge'], self.data['charge'])
        before = target.read_bytes()
        second = cw.incremental_import(directory, target)
        self.assertEqual(second['parsed'], [])
        self.assertEqual(target.read_bytes(), before)
        path = directory / 'charge.xlsx'
        original = path.read_bytes()
        try:
            path.write_bytes(b'invalid xlsx')
            with self.assertRaises(ValueError):
                cw.incremental_import(directory, target)
            self.assertEqual(target.read_bytes(), before)
        finally:
            path.write_bytes(original)


if __name__ == '__main__':
    unittest.main()
