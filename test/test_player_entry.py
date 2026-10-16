import importlib.util, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('launch',Path(__file__).resolve().parents[1]/'tools'/'play_main.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Validation(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name); self.p=self.root/'space-battleship'
  (self.p/'engine').mkdir(parents=True);(self.p/'bin').mkdir()
  (self.p/'engine/Godot_v4.7.2-stable_win64.exe').write_bytes(b'engine')
  (self.p/'bin/space_native.dll').write_bytes(b'accepted')
  (self.p/'space_native.gdextension').write_text(m.DESCRIPTOR)
  self.addCleanup(patch.stopall);patch.object(m,'ROOT',self.root).start()
  patch.object(m,'DLL_SHA',m.digest(self.p/'bin/space_native.dll')).start()
 def invoke(self,branch='main',changed=''):
  def fake(args,cwd,env=None):
   if '--show-current' in args:return branch
   if 'rev-parse' in args:return 'head'
   if 'diff' in args:return changed
   if '--version' in args:return '4.7.2.stable.official.x'
   return ''
  with patch.object(m,'run',side_effect=fake):return m.validate(self.root)
 def test_valid(self):self.assertEqual(self.invoke()[0],self.p)
 def test_wrong_branch(self):
  with self.assertRaises(RuntimeError):self.invoke(branch='candidate')
 def test_modified_source(self):
  with self.assertRaises(RuntimeError):self.invoke(changed='space-battleship/data/game_data.json')
 def test_wrong_dll(self):
  (self.p/'bin/space_native.dll').write_bytes(b'old')
  with self.assertRaises(RuntimeError):self.invoke()
 def test_external_descriptor(self):
  (self.p/'space_native.gdextension').write_text(m.DESCRIPTOR.replace('res://bin','D:/old'))
  with self.assertRaises(RuntimeError):self.invoke()
 def test_autoload_pack(self):
  (self.p/'engine/Godot_v4.7.2-stable_win64.pck').touch()
  with self.assertRaises(RuntimeError):self.invoke()
if __name__=='__main__':unittest.main()
