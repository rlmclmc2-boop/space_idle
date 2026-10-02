extends SceneTree
var checks:=0
func _initialize():call_deferred("run")
func run():
 var g=BattleGame.new(ShipDatabase.new(),false)
 g.profile.highestLevel=221;g.profile.cleared=range(1,221);g.rebuild_unlocks()
 for stage in range(1,221):
  var tiers:Array=["normal","normal","normal","normal","elite"] if stage<=5 else ["normal","normal","normal","normal","normal","elite","elite","elite","boss"]
  if stage>=20 and ((stage<=70 and stage%5==0) or (stage>70 and stage%10==0)):tiers=["elite","elite","elite","elite","elite","boss","boss","boss","ultimate"]
  assert(g.db.levels[stage-1].groups.size()==tiers.size())
  for node in range(tiers.size()):
   g.start(stage,false);g.group_index=node;g.spawn_group()
   assert(g.encounter_tier()==tiers[node])
   assert(g.is_final_encounter()==(node==tiers.size()-1))
   assert(g.is_boss_encounter()==(tiers[node] in ["boss","ultimate"]))
   for enemy in g.enemies:
    assert(enemy.combat_tier==tiers[node]);assert(enemy.boss==g.is_boss_encounter());enemy.hp=0
   g.tick(1.0/60.0)
   assert(g.state==(BattleGame.State.LEVEL_CLEAR if node==tiers.size()-1 else BattleGame.State.TRAVEL))
   checks+=1
 print("RUNTIME_TIER_PASS battle_points=",checks," stages=220 scope=source tier, enemy flags, final-only completion, special cadence; controlled kill fixture, not progression")
 quit()
