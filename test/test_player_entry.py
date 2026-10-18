import hashlib, importlib.util, tempfile, unittest
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
  (self.root/'tools/player_runtime').mkdir(parents=True)
  (self.root/'tools/player_runtime/space_native.dll').write_bytes(b'accepted')
  (self.p/'space_native.gdextension').write_text(m.DESCRIPTOR)
  self.addCleanup(patch.stopall);patch.object(m,'ROOT',self.root).start()
  patch.object(m,'DLL_SHA',m.digest(self.p/'bin/space_native.dll')).start()
 def invoke(self,branch='main',changed='',untracked=''):
  def fake(args,cwd,env=None):
   if '--show-current' in args:return branch
   if 'rev-parse' in args:return 'head'
   if 'diff' in args:return changed
   if 'ls-files' in args:return untracked
   if '--version' in args:return '4.7.2.stable.official.x'
   return ''
  with patch.object(m,'run',side_effect=fake):return m.validate(self.root)
 def test_valid(self):self.assertEqual(self.invoke()[0],self.p)
 def test_wrong_branch(self):
  with self.assertRaises(RuntimeError):self.invoke(branch='candidate')
 def test_modified_source(self):
  with self.assertRaises(RuntimeError):self.invoke(changed='space-battleship/data/game_data.json')
 def test_bounded_reading_files_allowed(self):
  changed='\n'.join(sorted(m.NON_RUNTIME_CHANGES))
  self.assertEqual(self.invoke(changed=changed)[0],self.p)
 def test_runtime_source_still_rejected_with_reading_files(self):
  changed='space-battleship/docs/READ_ROUTE.md\nspace-battleship/scripts/game.gd'
  with self.assertRaises(RuntimeError):self.invoke(changed=changed)
 def test_imported_evidence_translations_only(self):
  generated='space-battleship/docs/tasks/playtest-ui-art/evidence/enemy-slot-inventory.enemy.translation'
  self.assertEqual(self.invoke(untracked=generated)[0],self.p)
  with self.assertRaises(RuntimeError):self.invoke(untracked='space-battleship/assets/runtime.translation')
 def test_wrong_dll(self):
  (self.p/'bin/space_native.dll').write_bytes(b'old')
  with self.assertRaisesRegex(RuntimeError,'实际 SHA256'):
   self.invoke()
 def test_missing_dll(self):
  (self.p/'bin/space_native.dll').unlink()
  with self.assertRaisesRegex(RuntimeError,'缺少原生库'):
   self.invoke()
 def test_explicit_install_preserves_previous_dll(self):
  dll=self.p/'bin/space_native.dll'
  dll.write_bytes(b'old')
  with patch.object(m,'checked_source',return_value=(self.p,'head')):
   self.assertEqual(m.install_native(self.root),dll)
  self.assertEqual(dll.read_bytes(),b'accepted')
  backup=self.p/'.runtime/native-backup'/('space_native-'+hashlib.sha256(b'old').hexdigest()+'.dll')
  self.assertEqual(backup.read_bytes(),b'old')
 def test_explicit_install_supplies_missing_dll(self):
  dll=self.p/'bin/space_native.dll'
  dll.unlink()
  with patch.object(m,'checked_source',return_value=(self.p,'head')):
   self.assertEqual(m.install_native(self.root),dll)
  self.assertEqual(dll.read_bytes(),b'accepted')
 def test_explicit_install_rejects_bad_bundle(self):
  (self.root/'tools/player_runtime/space_native.dll').write_bytes(b'bad')
  with patch.object(m,'checked_source',return_value=(self.p,'head')):
   with self.assertRaisesRegex(RuntimeError,'Bundled native DLL'):
    m.install_native(self.root)
  self.assertEqual((self.p/'bin/space_native.dll').read_bytes(),b'accepted')
 def test_install_descriptor(self):
  (self.p/'space_native.gdextension').unlink()
  self.invoke()
  self.assertEqual((self.p/'space_native.gdextension').read_text(),m.DESCRIPTOR)
 def test_duplicate_descriptor(self):
  (self.p/'space_native.gdextension').unlink()
  (self.p/'other.gdextension').write_text(m.DESCRIPTOR)
  with self.assertRaisesRegex(RuntimeError,'重复原生库入口'):
   self.invoke()
  self.assertFalse((self.p/'space_native.gdextension').exists())
 def test_external_descriptor(self):
  (self.p/'space_native.gdextension').write_text(m.DESCRIPTOR.replace('res://bin','D:/old'))
  with self.assertRaises(RuntimeError):self.invoke()
 def test_autoload_pack(self):
  (self.p/'engine/Godot_v4.7.2-stable_win64.pck').touch()
  with self.assertRaises(RuntimeError):self.invoke()
if __name__=='__main__':unittest.main()
