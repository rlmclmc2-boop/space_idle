"""Exercise source editing only in test/run.py's isolated workspace."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from level_editor_store import Store
from config_workbooks import incremental_import


class EditorTests(unittest.TestCase):
    def setUp(self):
        self.store = Store(ROOT)
        self.original = {p: p.read_bytes() for p in [*self.store.paths.values(), self.store.target, self.store.manifest]}
        self.request = self.store.load()

    def tearDown(self):
        for path, raw in self.original.items(): path.write_bytes(raw)

    def test_roundtrip_and_incremental(self):
        r = self.request
        enemy = copy.deepcopy(r['tables']['mon']['rows'][0])
        enemy.update(id=999, des='测试飞行器', health=321)
        r['tables']['mon']['rows'].append(enemy)
        group = {'id': 999, 'des': '测试编队', 'mon': '{null,null,null,null,999,null,null,null,null,null}'}
        r['tables']['monGroup']['rows'].append(group)
        level = r['tables']['level']['rows'][0]
        level['monGroup'] = '{999|0.1,' + str(level['monGroup']).strip('{}')[0:] + '}'
        # Replace a first encounter without duplicating its position.
        level['monGroup'] = '{999|0.01,6|0.9}'
        level['atkRatio'] = 2
        result = self.store.execute(r, True)
        data = json.loads(self.store.target.read_text(encoding='utf-8'))
        self.assertEqual(data['enemies']['999']['health'], 321)
        self.assertEqual(data['groups']['999']['slots'][4], 999)
        self.assertEqual(data['levels'][0]['lifeRatio'], 2)
        self.assertEqual(data['levels'][1]['atkRatio'], 2.34)
        self.assertTrue(Path(result['backup']).is_dir())
        self.assertEqual(result['tables']['level']['rows'][0]['lifeRatio'], '=D4')
        self.assertEqual(incremental_import(self.store.directory, self.store.target)['changed'], [])
        with zipfile.ZipFile(self.store.paths['level']) as changed, zipfile.ZipFile(__import__('io').BytesIO(self.original[self.store.paths['level']])) as original:
            self.assertEqual(changed.read('xl/styles.xml'), original.read('xl/styles.xml'))
        # Delete the newly added records after removing their references.
        result['tables']['level']['rows'][0]['monGroup'] = '{6|0.9}'
        result['tables']['monGroup']['rows'].pop()
        result['tables']['mon']['rows'].pop()
        self.store.execute(result, True)
        self.assertNotIn('999', json.loads(self.store.target.read_text(encoding='utf-8'))['enemies'])

    def test_conflict_preserves_files(self):
        p = self.store.target
        p.write_bytes(p.read_bytes() + b'\n')
        changed = p.read_bytes()
        with self.assertRaisesRegex(ValueError, '修改'): self.store.execute(self.request, True)
        self.assertEqual(p.read_bytes(), changed)

    def test_bad_inputs_do_not_write(self):
        changes = [
            ('mon', 'id', 2), ('mon', 'health', -1), ('mon', 'size', 1.5),
            ('mon', 'equipment', '{missing|1}'), ('mon', 'res', '{999,1,1}'),
            ('monGroup', 'mon', '{999,null,null,null,null,null,null,null,null,null}'),
            ('level', 'monGroup', '{1|0.2,2|0.1}'), ('level', 'atkRatio', '=D4'),
            ('level', 'atkRatio', '=SUM(D5:D6)'), ('level', 'id', 100),
        ]
        for name, key, value in changes:
            with self.subTest(name=name, key=key):
                request = copy.deepcopy(self.request)
                request['tables'][name]['rows'][0][key] = value
                with self.assertRaises((ValueError, KeyError)): self.store.execute(request, True)
                self.assertEqual(self.store.target.read_bytes(), self.original[self.store.target])

    def test_validation_is_read_only(self):
        self.request['tables']['mon']['rows'][0]['health'] = 200
        self.store.execute(self.request)
        for path, raw in self.original.items(): self.assertEqual(path.read_bytes(), raw)

    def test_godot_float_ids(self):
        for table in self.request['tables'].values():
            for row in table['rows']:
                for key, value in row.items():
                    if type(value) is int: row[key] = float(value)
        self.request['tables']['monGroup']['rows'][0]['des'] = '浮点传输测试'
        self.store.execute(self.request, True)
        self.assertIn('1', json.loads(self.store.target.read_text(encoding='utf-8'))['groups'])

    def test_final_battle_does_not_require_large_hull(self):
        rows = self.request['tables']['mon']['rows']
        small = next(r['id'] for r in rows if r['size'] == 1)
        large = next(r['id'] for r in rows if r['size'] > 1)
        self.request['tables']['monGroup']['rows'].extend([
            {'id': 998, 'des': '前置大型舰', 'mon': '{' + str(large) + ',null,null,null,null,null,null,null,null,null}'},
            {'id': 999, 'des': '最后普通舰', 'mon': '{' + str(small) + ',null,null,null,null,null,null,null,null,null}'},
        ])
        self.request['tables']['level']['rows'][0]['monGroup'] = '{998|0.2,999|0.9}'
        result = self.store.execute(self.request)
        self.assertFalse(any('没有 BOSS' in w or '不会执行' in w for w in result['warnings']))

    def test_failed_commit_rolls_back(self):
        import config_workbooks
        real_replace = config_workbooks.os.replace
        def fail_target(source, target):
            if Path(target) == self.store.target: raise OSError('simulated locked JSON')
            real_replace(source, target)
        self.request['tables']['mon']['rows'][0]['health'] = 200
        with patch.object(config_workbooks.os, 'replace', side_effect=fail_target):
            with self.assertRaises(OSError): self.store.execute(self.request, True)
        for path, raw in self.original.items(): self.assertEqual(path.read_bytes(), raw)


if __name__ == '__main__': unittest.main()
