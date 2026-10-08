"""Contracts for the authorized forty dedicated hyperspace formations.

Structural checks only; real combat outcomes and player acceptance remain separate.
"""
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]/'space-battleship'
class DedicatedRoutes(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.c=json.loads((ROOT/'data/space_enemy_candidates.json').read_text());cls.r=json.loads((ROOT/'data/space_enemy_routes.json').read_text());cls.cfg=json.loads((ROOT/'data/hyperspace_config.json').read_text());cls.main=json.loads((ROOT/'data/game_data.json').read_text());cls.rec=json.loads((ROOT/'data/space_enemy_reward_recipes.json').read_text());cls.catalog=json.loads((ROOT/'data/space_enemy_reward_catalog.json').read_text())
 def test_all_forty_are_custom_non_resistant_and_ordered(self):
  seen=[]
  for route in self.cfg['routes'].values():
   weapon=route['weapon'];damage=int(self.main['equipment'][weapon][0]['dmgtype']);previous_hp=previous_dps=0
   for tier,count in [('normal',4),('elite',4),('boss',1),('ultimate',1)]:
    ids=self.r['routes'][weapon][tier];self.assertEqual(count,len(ids))
    for gid in ids:
     with self.subTest(route=weapon,group=gid):
      seen.append(gid);g=self.c['groups'][str(gid)];self.assertEqual(tier,g['combatTier']);members=[self.c['enemies'][str(e)] for e in g['slots'] if e is not None]
      installations={w['name'] for e in members for w in e['equipment']};self.assertEqual(1,len(installations),'No legacy mixed-family quota')
      hp=sum(e['health']+e['shield'] for e in members);self.assertGreater(hp,previous_hp);previous_hp=hp
      dps=0
      for e in members:
       self.assertNotEqual(damage,e['armourType']);self.assertIn(e['armourType'],[1,2],'Retain real resistance against other damage class')
       if e['shield']:self.assertNotEqual(damage,e['shieldType'])
       self.assertEqual(1,len(e['equipment']))
       w=self.main['equipment'][e['equipment'][0]['name']][0];dps+=w['dmg']/w['cd']*e['dmgMultiple']
      self.assertGreater(dps,previous_dps);previous_dps=dps
      if tier in ['boss','ultimate']:
       self.assertLessEqual(len(members),3)
       leader=max(members,key=lambda e:e['health']+e['shield']);self.assertGreaterEqual((leader['health']+leader['shield'])/hp,.70)
       leader_slot=g['slots'].index(leader['id']);self.assertEqual(286,g['formation_positions'][leader_slot][0])
       for e in members:
        if e!=leader:self.assertGreater(g['formation_positions'][g['slots'].index(e['id'])][1],g['formation_positions'][leader_slot][1],'Screen is reachable before leader under unchanged front-first tie-break')
  self.assertEqual(40,len(seen));self.assertEqual(40,len(set(seen)))
 def test_all_source_reward_blocks_survive_once(self):
  for gid,g in self.c['groups'].items():
   with self.subTest(group=gid):
    members=self.rec['groups'][gid];slots={i for i,e in enumerate(g['slots']) if e is not None}
    self.assertEqual(slots,{m['slot'] for m in members});self.assertEqual(len(slots),len(members))
    blocks=[o for m in members for o in m['reference_member_ordinals_for_resource_blocks']]
    ref=self.catalog['references'][g['rewardBinding']['rewardReferenceDesignId']]
    self.assertEqual(list(range(ref['reference_member_count'])),sorted(blocks))
    self.assertEqual(sum(m['jewelDropRolls'] for m in members),ref['reference_member_count'])
 def test_mainline_and_level_policy_stay_separate(self):
  self.assertTrue(set(self.c['enemies']).isdisjoint(self.main['enemies']));self.assertTrue(set(self.c['groups']).isdisjoint(self.main['groups']))
  policy=self.r['selected_mainline_level_policy'];self.assertEqual('inherit_selected_mainline_level',policy['atkRatio']);self.assertEqual('inherit_selected_mainline_level',policy['lifeRatio']);self.assertEqual(0,policy['enemy_tier_offset'])
if __name__=='__main__':unittest.main()
