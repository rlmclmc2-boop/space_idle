"""Static package closure failures independent of a Godot installation."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from script_dependencies import closure
import build_result_analyzer as builder


class PackageClosure(unittest.TestCase):
    def test_current_entry(self):
        manifest = builder.required_files()
        self.assertIn('economy_state.gd', manifest['scripts'])
        self.assertIn('progress_runtime.gd', manifest['scripts'])
        self.assertIn('database.gd', manifest['scripts'])
        self.assertNotIn('main.gd', manifest['scripts'])
        self.assertNotIn('hyperspace_main_return.gd', manifest['scripts'])
        self.assertNotIn('scripts', json.loads(builder.MANIFEST.read_text(encoding='utf-8')))

    def test_scene_classes_cycles_and_literals(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            (root / 'main.tscn').write_text('[ext_resource path="res://scripts/a.gd"]')
            (root / 'scripts/a.gd').write_text('extends Parent\n# Ghost\nvar note="Ghost"\nvar data=load("res://data/live.json")')
            (root / 'scripts/b.gd').write_text('class_name Parent\nconst A=preload("res://scripts/a.gd")')
            (root / 'scripts/ghost.gd').write_text('class_name Ghost\n')
            files, resources = closure(root, ['main.tscn'])
            self.assertEqual(files, {'main.tscn', 'scripts/a.gd', 'scripts/b.gd'})
            self.assertEqual(resources, {'data/live.json'})
            (root / 'scripts/a.gd').write_text('extends "res://scripts/removed.gd"')
            with self.assertRaises(FileNotFoundError):
                closure(root, ['main.tscn'])

    def test_missing_resource_declaration_rejected(self):
        with patch.object(builder, 'closure', return_value=(set(), {'data/unlisted.json'})):
            with self.assertRaisesRegex(ValueError, 'Undeclared analyzer resource'):
                builder.required_files()

    def test_duplicate_classes_and_escape_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            for name in ['a', 'b']:
                (root / 'scripts' / (name + '.gd')).write_text('class_name Duplicate\n')
            with self.assertRaisesRegex(ValueError, 'Duplicate class_name'):
                closure(root, ['scripts/a.gd'])
            (root / 'scripts/b.gd').unlink()
            with self.assertRaisesRegex(ValueError, 'Invalid project dependency'):
                closure(root, ['../outside.gd'])

    def test_entrypoint_locations(self):
        index = json.loads((ROOT / 'tools/supported_entrypoints.json').read_text(encoding='utf-8'))
        for entry in index['entries'].values():
            for name in entry['roots']:
                self.assertTrue((ROOT / name).is_file(), name)
            self.assertTrue((ROOT / 'tools' / entry['verification']).is_file(), entry['verification'])


if __name__ == '__main__':
    unittest.main()
