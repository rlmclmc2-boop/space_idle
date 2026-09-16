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
        # Replace a first encounter without duplicating its position.
        level['monGroup'] = '{999|0.01,6|0.9}'
        original_ratios = copy.deepcopy(r['tables']['level']['rows'])
        level['atkRatio'] = 2
        # Known formula chain tests cache recalculation independently of balance edits.
        level['lifeRatio'] = '=D4'
        r['tables']['level']['rows'][1]['atkRatio'] = '=ROUND(D4*1.17,2)'
        result = self.store.execute(r, True)
        data = json.loads(self.store.target.read_text(encoding='utf-8'))
        self.assertEqual(data['enemies']['999']['health'], 321)
        self.assertEqual(data['groups']['999']['slots'][4], 999)


        self.assertTrue(Path(result['backup']).is_dir())
        self.assertEqual(result['tables']['level']['rows'][0]['lifeRatio'], original_ratios[0]['lifeRatio'])
        self.assertEqual(result['tables']['level']['rows'][1]['atkRatio'], original_ratios[1]['atkRatio'])
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

    def test_ratios_are_preserved_without_validation(self):
        from lxml import etree as ET
        from config_workbooks import Q, sheet_parts
        import io
        path = self.store.paths['level']
        with zipfile.ZipFile(path) as archive:
            part = dict(sheet_parts(archive))['level']
            tree = ET.fromstring(archive.read(part))
            cells = {c.get('r'): c for c in tree.iter(Q+'c')}
            for address, raw in [('D4', '=UNSUPPORTED(D4)'), ('E4', '-5'), ('F4', '0')]:
                cell = cells[address]
                for child in list(cell): cell.remove(child)
                cell.attrib.pop('t', None)
                ET.SubElement(cell, Q+('f' if raw.startswith('=') else 'v')).text = raw.lstrip('=')
            expected = {a: ET.tostring(cells[a]) for a in ['D4','E4','F4']}
            output = io.BytesIO()
            with zipfile.ZipFile(output, 'w') as target:
                for item in archive.infolist(): target.writestr(item, ET.tostring(tree) if item.filename == part else archive.read(item.filename))
        path.write_bytes(output.getvalue())
        request = self.store.load()
        request['tables']['level']['rows'][0]['length'] = 1234
        self.store.execute(request)
        self.store.execute(request, True)
        with zipfile.ZipFile(path) as archive:
            cells = {c.get('r'): c for c in ET.fromstring(archive.read(part)).iter(Q+'c')}
            for address, raw in expected.items(): self.assertEqual(ET.tostring(cells[address]), raw)
        from import_workbook import validate_projection
        data = json.loads(self.store.target.read_text(encoding='utf-8'))
        with self.assertRaises(ValueError): validate_projection(data)

    def test_bad_inputs_do_not_write(self):
        changes = [
            ('mon', 'id', 2), ('mon', 'health', -1), ('mon', 'size', 1.5),
            ('mon', 'equipment', '{missing|1}'), ('mon', 'res', '{999,1,1}'),
            ('monGroup', 'mon', '{999,null,null,null,null,null,null,null,null,null}'),
            ('level', 'monGroup', '{1|0.2,2|0.1}'),
             ('level', 'id', 100),
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

    def test_large_ships_each_use_one_slot(self):
        enemy = self.request['tables']['mon']['rows'][0]
        enemy['size'] = 100
        self.request['tables']['monGroup']['rows'][0]['mon'] = '{' + ','.join([str(enemy['id'])] * 10) + '}'
        result = self.store.execute(self.request)
        self.assertFalse(any('占格' in w or '越界' in w for w in result['warnings']))


if __name__ == '__main__': unittest.main()
