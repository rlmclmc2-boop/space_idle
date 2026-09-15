import copy
import json
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
import config_workbooks as cw

class ScientistConfig(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))
    def test_actual_projection(self):
        for name in ('config', 'hightech'):
            path = ROOT / 'config_excel' / (name + '.xlsx')
            self.assertEqual(self.data[name], cw.read_changed_file(path,name,path.read_bytes()))
        cw.validate_projection(self.data)
    def test_fractional_exponent(self):
        self.data['config']['hightechLimit'] = 0.8
        cw.validate_projection(self.data)
    def test_invalid_costs(self):
        for cost in ('', '1.3', '1,999|10', '1,1|-1', '1,1|2,1|3', 'nan,1|10'):
            with self.subTest(cost=cost):
                self.data['config']['scientistCost'] = cost
                with self.assertRaises(ValueError): cw.validate_projection(self.data)
    def test_invalid_point_parameters(self):
        for field in ('hightechLimit', 'techPointGet'):
            bad = copy.deepcopy(self.data)
            bad['config'][field] = 0
            with self.assertRaises(ValueError): cw.validate_projection(bad)
        bad = copy.deepcopy(self.data)
        row = next(iter(bad['hightech'].values()))
        row['tpCostBase'] = 0.1
        with self.assertRaises(ValueError): cw.validate_projection(bad)
    def test_old_time_fields_not_used(self):
        for row in self.data['hightech'].values():
            row['timeCostBase'] = -999
            row['timeCostMutiple'] = -999
        cw.validate_projection(self.data)
    def test_multiple_currencies(self):
        self.data['resources']['3'] = 'test'
        self.data['config']['scientistCost'] = '1.3,1|100,2|10,3|5'
        cw.validate_projection(self.data)

if __name__ == '__main__': unittest.main(verbosity=2)
