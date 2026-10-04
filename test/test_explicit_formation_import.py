"""Excel projection/slot identity boundary checks; no battle simulation."""
import copy
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from import_workbook import convert_sheet
from explicit_formation import validate

class ImportContract(unittest.TestCase):
    def setUp(self):
        self.enemies={'1':{'size':4},'2':{'size':1}}
        self.row={'id':7001,'des':'candidate','mon':'1,2,'+','.join(['null']*13),'combatTier':'normal'}
        self.points=[[286,140],[166,230]]+[None]*13
    def test_blank_preserves_old_projection(self):
        before=convert_sheet('monGroup',[self.row])
        after=convert_sheet('monGroup',[dict(self.row,formation_positions='')])
        self.assertEqual(before,after)
    def test_excel_json_preserves_slot_coordinates(self):
        group=convert_sheet('monGroup',[dict(self.row,formation_positions=json.dumps(self.points))])['7001']
        validate(group,self.enemies)
        self.assertEqual(group['formation_positions'],self.points)
        self.assertEqual(group['slots'][:2],[1,2])
    def test_bad_coordinates_are_rejected(self):
        for points in [self.points[:-1],[[286,float('nan')]]+self.points[1:],[[286,360]]+self.points[1:],[[286,260]]+self.points[1:],[[286,140],[286,140]]+[None]*13,self.points[:2]+[[1,2]]+[None]*12]:
            with self.assertRaises(ValueError):validate({'slots':[1,2]+[None]*13,'formation_positions':points},self.enemies)

if __name__=='__main__':unittest.main()
