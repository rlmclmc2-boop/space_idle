"""Run via run.py: catalog contract, editor writes, conflict and UI-source audit."""
import copy
import json
from pathlib import Path
import re
import sys
import threading
import unittest
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
import ui_text
import ui_text_editor as editor

STATIC_UI_KEY = re.compile(r'UIText\.t\("([^"]+)"(?!\s*\+)')


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.raw = ui_text.CATALOG.read_bytes()
        self.document = editor.read_document()

    def tearDown(self):
        ui_text.CATALOG.write_bytes(self.raw)
        ui_text._texts = None

    def test_delete_restore_and_contract(self):
        for key, values in [('battle.hp', {'current_hp':850, 'max_hp':1000}), ('weapon.laser_name', {})]:
            before = editor.read_document()
            request = {'revision':before['revision'], 'key':key, 'deleted':True}
            result = editor.set_deleted(request)
            after = editor.read_document()
            for old, new in zip(before['rows'], after['rows']):
                self.assertEqual(new, {**old, 'deleted':True} if old['key']==key else old)
            ui_text._texts = None
            self.assertEqual(ui_text.t(key, **values), '')
            with self.assertRaises(ValueError): editor.set_deleted(request)
            edits = {r['key']:r['text'] for r in after['rows']}
            if values:
                edits[key] = '{hp}'
                with self.assertRaises(ValueError): editor.save_document({'revision':result['revision'], 'texts':edits})
            editor.set_deleted({'revision':result['revision'], 'key':key, 'deleted':False})
            ui_text._texts = None
            self.assertTrue(ui_text.t(key, **values))
            self.assertEqual(editor.read_document()['rows'], before['rows'])

    def request(self):
        return {'revision': self.document['revision'], 'texts': {r['key']: r['text'] for r in self.document['rows']}}

    def test_all_parameters_and_keys(self):
        self.assertEqual(self.document['errors'], [])
        keys = {r['key'] for r in self.document['rows']}
        for key in keys:
            self.assertRegex(key, r'^[a-z][a-z0-9_.]*$')
        for path in (ROOT / 'scripts').glob('*.gd'):
            for key in STATIC_UI_KEY.findall(path.read_text(encoding='utf-8')):
                self.assertIn(key, keys, str(path))
        for row in self.document['rows']:
            if row['params']:
                bad = copy.deepcopy(self.document['rows'])
                index = self.document['rows'].index(row)
                token = re.findall(r'\{[^{}]+\}', row['params'])[0]
                bad[index]['text'] = row['text'].replace(token, '', 1)
                self.assertTrue(ui_text.validate(bad), row['key'])

    def test_static_key_scan_skips_concatenated_prefix(self):
        source = 'UIText.t("equipment.state."+item.status)\nUIText.t("equipment.state.equipped")'
        self.assertEqual(STATIC_UI_KEY.findall(source), ['equipment.state.equipped'])

    def test_save_plain_text_preserves_every_other_column(self):
        request = self.request()
        request['texts']['battle.hp'] = '耐久：{current_hp}/{max_hp}'
        result = editor.save_document(request)
        saved = editor.read_document()
        self.assertEqual(saved['revision'], result['revision'])
        for before, after in zip(self.document['rows'], saved['rows']):
            self.assertEqual({k:v for k,v in before.items() if k!='text'}, {k:v for k,v in after.items() if k!='text'})
        with self.assertRaises(ValueError):
            editor.save_document(request)

    def test_invalid_interface_edits_never_write(self):
        for text in ['耐久：{hp}/{max_hp}', '耐久：{current_hp}', '{current_hp}/{max_hp}/{new}', '{current_hp}/{max_hp}{', '{current_hp}/{current_hp}/{max_hp}']:
            request = self.request()
            request['texts']['battle.hp'] = text
            with self.assertRaises(ValueError): editor.save_document(request)
            self.assertEqual(ui_text.CATALOG.read_bytes(), self.raw)
        request = self.request()
        del request['texts']['battle.hp']
        with self.assertRaises(ValueError): editor.save_document(request)
        self.assertEqual(ui_text.CATALOG.read_bytes(), self.raw)

    def test_http_contract(self):
        server, url = editor.make_server()
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = url.split('/?')[0]
        token = url.split('token=')[1]
        try:
            with urllib.request.urlopen(url) as response:
                self.assertIn('textarea', response.read().decode())
            with self.assertRaises(urllib.error.HTTPError): urllib.request.urlopen(base+'/catalog')
            headers = {'X-UI-Token':token, 'Content-Type':'application/json'}
            request = self.request()
            request['texts']['battle.hp'] = '耐久：{max_hp}/{current_hp}'
            bad = urllib.request.Request(base+'/save', json.dumps(request).encode(), {**headers,'Origin':'https://example.com'})
            with self.assertRaises(urllib.error.HTTPError): urllib.request.urlopen(bad)
            self.assertEqual(ui_text.CATALOG.read_bytes(), self.raw)
            good = urllib.request.Request(base+'/save', json.dumps(request).encode(), headers)
            with urllib.request.urlopen(good) as response: self.assertEqual(response.status,200)
        finally:
            server.shutdown()
            server.server_close()

    def test_no_new_hardcoded_chinese_in_game_scripts(self):
        # These are existing configuration IDs/formula syntax/path interfaces,
        # never visible prose. Extending this allowlist requires a documented reason.
        allowed = {
            'database.gd': {'历史攻击次数','受到过的伤害次数','额外*(1+','电子干扰','连续para4秒','额外发射','固定增加该武器para2暴击','CD立即结束','该伤害-','不会因受到伤害而打断'},
            'game.gd': {'超时空炼铁炉','宝石熔炼炉','过去一分钟的宝石碎片生成量','正电子聚焦装置','简并态装甲','防御充能','攻击充能','熔炼器充能','过去一分钟的铁生成量','不含自身','等级','向上取整','百分比显示','保留两位小数','即100.3%展示为100%','百分比','四舍五入保留整数百分比部分'},
            'main.gd': {'防御充能','攻击充能'},
            'jewel_panel.gd': {'等级','武器攻击次数','承受攻击次数'},
            'config_panel.gd': {'res://../太空战舰.xlsx'},
        }
        tokens = re.compile(r'"(?:\\.|[^"\\])*"|#[^\n]*')
        for path in (ROOT/'scripts').glob('*.gd'):
            for match in tokens.finditer(path.read_text(encoding='utf-8')):
                if match[0].startswith('#'): continue
                value = json.loads(match[0])
                if re.search(r'[\u3400-\u9fff]',value):
                    self.assertIn(value, allowed.get(path.name,set()), f'{path.name}: add display prose to the UI catalog')


if __name__ == '__main__':
    unittest.main()
