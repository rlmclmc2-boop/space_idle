"""Wave combat overrides preserve source/projection and reject malformed factors."""
import copy
import contextlib
import io
import math
import shutil
import tempfile
import json
import pathlib
import sys
import unittest
import openpyxl
ROOT=pathlib.Path(__file__).resolve().parents[1]/'space-battleship'
sys.path.insert(0,str(ROOT/'tools'))
from import_workbook import convert_sheet, read_rows, validate_projection
from smooth_wave_curve import smooth

class WaveGateImport(unittest.TestCase):
 def test_live_source_projection(self):
  with open(ROOT/'data/game_data.json',encoding='utf8') as f:data=json.load(f)
  book=openpyxl.load_workbook(ROOT/'config_excel/monGroup.xlsx',read_only=True,data_only=True)
  self.assertEqual(convert_sheet('monGroup',read_rows(book['monGroup'])),data['groups'])
  book.close()
  validate_projection(data)
 def test_optional_factors_and_rejections(self):
  row={'id':1,'des':'fixture','mon':'{1,null,null,null,null,null,null,null,null,null}'}
  self.assertNotIn('lifeMultiplier',convert_sheet('monGroup',[dict(row,lifeMultiplier='')])['1'])
  valid=convert_sheet('monGroup',[dict(row,lifeMultiplier=2.5,atkMultiplier=0.75)])['1']
  self.assertEqual((valid['lifeMultiplier'],valid['atkMultiplier']),(2.5,0.75))
  self.assertNotIn('authorAtkScale',convert_sheet('monGroup',[dict(row,authorAtkScale=0.125)])['1'])
  for key in ['lifeMultiplier','atkMultiplier','authorAtkScale']:
   for value in [0,-1,float('nan'),float('inf'),True,'2']:
    with self.subTest(key=key,value=value),self.assertRaises(ValueError):
     convert_sheet('monGroup',[dict(row,**{key:value})])
 def test_author_shape_survives_full_middle_curve_rebuild(self):
  expected=json.loads((ROOT/'data/game_data.json').read_text())['groups']
  with tempfile.TemporaryDirectory() as directory:
   path=pathlib.Path(directory)
   for name in ['level.xlsx','monGroup.xlsx']:
    shutil.copy2(ROOT/'config_excel'/name,path/name)
   with contextlib.redirect_stdout(io.StringIO()):smooth(path,range(11,21),True)
   book=openpyxl.load_workbook(path/'monGroup.xlsx',read_only=True,data_only=True)
   actual=convert_sheet('monGroup',read_rows(book['monGroup']));book.close()
  self.assertEqual(set(actual),set(expected))
  for gid,group in expected.items():
   for key in ['atkMultiplier','lifeMultiplier']:
    if key in group:
     self.assertTrue(math.isclose(actual[gid][key],group[key],rel_tol=1e-12),f'{gid}/{key}')
     actual[gid][key]=group[key]
   self.assertEqual(actual[gid],group)
 def test_projection_revalidates_factors(self):
  data=json.loads((ROOT/'data/game_data.json').read_text())
  gid=str(data['levels'][10]['groups'][0]['id'])
  for value in [0,-1,float('nan'),float('inf'),True,'2']:
   fixture=copy.deepcopy(data);fixture['groups'][gid]['lifeMultiplier']=value
   with self.subTest(value=value),self.assertRaises(ValueError):validate_projection(fixture)

if __name__=='__main__':unittest.main()
