"""Entity XLSX defaults, ordering, rejection and four-output transaction boundary."""
import copy
import hashlib
import json
from pathlib import Path
import random
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]/'space-battleship'
sys.path.insert(0,str(ROOT/'tools'))
import hyperspace_entities as h
import config_workbooks as cw

class EntityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema=h.load_schema();cls.data=ROOT/'data'
        cls.raw={n:(ROOT/'config_excel'/n).read_bytes() for n in ['hyperspace_config.xlsx','hyperspace_enemies.xlsx']}
        cls.tables=h.parse_tables(cls.raw)
        cls.main=json.loads((cls.data/'game_data.json').read_text())
        cls.frozen={n:json.loads((cls.data/n).read_text()) for n in cls.schema['frozen_inputs']}
        cls.default=h.project_tables(cls.tables,cls.main,cls.frozen)
    def rows(self,t,name):return t[('hyperspace_config.xlsx' if name in ['基础参数','品质','传说随机参数','词缀定义'] else 'hyperspace_enemies.xlsx',name)]
    def reject(self,mutate):
        t=copy.deepcopy(self.tables);mutate(t)
        with self.assertRaises((ValueError,KeyError)):h.project_tables(t,self.main,self.frozen)
    def test_formal_defaults(self):
        for name,v in self.default.items():self.assertEqual(v,json.loads((self.data/name).read_text()))
        self.assertEqual(85,sum(not m['reference_member_ordinals_for_resource_blocks'] for a in self.default['space_enemy_reward_recipes.json']['groups'].values() for m in a))
        self.assertEqual(40,sum(0 in m['reference_member_ordinals_for_resource_blocks'] for a in self.default['space_enemy_reward_recipes.json']['groups'].values() for m in a))
    def test_all_tables_shuffle_identical_bytes(self):
        t=copy.deepcopy(self.tables)
        for rows in t.values():random.Random(37).shuffle(rows)
        self.assertEqual(json.dumps(self.default),json.dumps(h.project_tables(t,self.main,self.frozen)))
    def test_valid_distinct_coefficients(self):
        t=copy.deepcopy(self.tables)
        for r in self.rows(t,'基础参数'):
            if r['key'] in ['modernization_base_coefficient','auto_duration_crew_base','auto_ticket_crew_base']:r['value']*=2
            if r['key']=='amplification_start_level':r['value']=6
        o=h.project_tables(t,self.main,self.frozen)['hyperspace_config.json']
        self.assertEqual([2,200,40,6],[o[k] for k in ['modernization_base_coefficient','auto_duration_crew_base','auto_ticket_crew_base','amplification_start_level']])
    def test_locked_overflow_and_structure(self):
        self.reject(lambda t:next(r for r in self.rows(t,'基础参数') if r['key']=='overflow_capacity').update(value=11))
        self.reject(lambda t:self.rows(t,'词缀定义')[0].update(amplified=not self.rows(t,'词缀定义')[0]['amplified']))
    def test_types_and_ranges(self):
        for value in [True,float('inf'),0,'100']:
            self.reject(lambda t,v=value:next(r for r in self.rows(t,'基础参数') if r['key']=='auto_duration_crew_base').update(value=v))
        self.reject(lambda t:next(r for r in self.rows(t,'传说随机参数') if r['parameter']=='maximum_dodge').update(maximum=1.1))
        self.reject(lambda t:next(r for r in self.rows(t,'基础参数') if r['key']=='maximum_equipped').update(value=6))
    def test_references_recipe_zero_and_order(self):
        self.reject(lambda t:self.rows(t,'路线编排')[0].update(group_id=999999))
        self.reject(lambda t:self.rows(t,'成员分配')[0].update(reference_member_ordinal=999))
        self.reject(lambda t:next(r for r in self.rows(t,'成员分配') if r['order'] is None).update(reference_member_ordinal=0))
        self.reject(lambda t:self.rows(t,'敌人')[0].update(order=3))
    def test_frozen_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            d=Path(tmp)
            for n in self.schema['frozen_inputs']:shutil.copyfile(self.data/n,d/n)
            (d/'space_enemy_reward_sources.json').write_text('{}')
            with self.assertRaises(ValueError):h.read_bundle(self.raw,self.main,d)
    def test_formal_incremental_noop_and_four_output_rollback(self):
        with tempfile.TemporaryDirectory() as tmp:
            area=Path(tmp);folder=area/'config_excel';data=area/'data'
            shutil.copytree(ROOT/'config_excel',folder);shutil.copytree(self.data,data)
            target=data/'game_data.json';cw.incremental_import(folder,target)
            paths=[data/n for n in [*self.default,'.import_state.json','game_data.json']]
            before={p:(p.read_bytes(),p.stat().st_mtime_ns) for p in paths}
            self.assertEqual([],cw.incremental_import(folder,target)['changed'])
            self.assertEqual(before,{p:(p.read_bytes(),p.stat().st_mtime_ns) for p in paths})
            # Force all four outputs to require writing. Real parent workbooks stay untouched.
            for n in self.default:(data/n).write_text('{}')
            before={p:p.read_bytes() for p in paths}
            original=cw.os.replace
            def fail_last(source,destination):
                if Path(destination).name=='space_enemy_reward_recipes.json':raise OSError('injected final output failure')
                return original(source,destination)
            with patch.object(cw.os,'replace',side_effect=fail_last):
                with self.assertRaises(OSError):cw.incremental_import(folder,target)
            self.assertEqual(before,{p:p.read_bytes() for p in paths})

if __name__=='__main__':unittest.main()
