"""Validate mon quantity projection without changing source workbooks."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from import_workbook import convert_sheet


class Counts(unittest.TestCase):
    def convert(self, value):
        return convert_sheet('mon', [{'id': 1, 'equipment': value, 'res': '{1,10,1}'}])['1']['equipment']

    def test_counts_and_order(self):
        self.assertEqual(self.convert('{laser_mon|2,cannon-mon|1,laser_mon|3}'),
                         [{'name': 'laser_mon'}] * 2 + [{'name': 'cannon-mon'}] + [{'name': 'laser_mon'}] * 3)

    def test_invalid_counts(self):
        for value in ('0', '-1', '1.5', '', 'x'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.convert('{laser_mon|' + value + '}')


if __name__ == '__main__':
    unittest.main()
