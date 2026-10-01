extends SceneTree
# Formal player weapon projection; synthetic stationary target geometry only.
const N=preload("res://scripts/growth_number.gd")
const Presented=preload("res://scripts/presented_battle_game.gd")
const SEEDS=[107,211,307,401,503,601,701,809]
const EXTRA_SEEDS=[907,1009,1103,1201,1301,1409,1511,1601]
var rows=[]
class Observed extends Presented:
 var counts={}
 var dealt=0.0
 var kills=[]
 var queued_payload=0.0
 var released_payload=0.0
 var raw_hit_payload=0.0
 var queue_peak=0
 var group_serial=0
 var groups={}
 var releases=[]
 func _init(db):
  super(db,false)
  event.connect(func(kind,_payload):counts["event_"+kind]=counts.get("event_"+kind,0)+1)
 func begin_enhancement_attack(index,target,derived=false,track_primary=true):
  if not derived:
   var kind="primary" if track_primary else "extra_repeat"
   counts[kind]=counts.get(kind,0)+1
  return super.begin_enhancement_attack(index,target,derived,track_primary)
 func jewel_attack(index,multiplier=1.0):
  var attack=super.jewel_attack(index,multiplier)
  counts["attack_resolution"]=counts.get("attack_resolution",0)+1
  if attack.critical:counts["critical_event"]=counts.get("critical_event",0)+1
  return attack
 func launch_player_attack(index,target,weapon,attack,offset,spread,salvo_index=0,salvo_count=1):
  if salvo_index==0:
   group_serial+=1
   groups[group_serial]={"expected":salvo_count,"committed":0,"released":0,"ordinals":[],"due":[]}
  queued_payload+=float(attack.damage)
  counts["committed_packets"]=counts.get("committed_packets",0)+1
  groups[group_serial].committed+=1
  super.launch_player_attack(index,target,weapon,attack,offset,spread,salvo_index,salvo_count)
  missile_queue.back().observed_group=group_serial
  queue_peak=maxi(queue_peak,missile_queue.size())
 func prepare_projectile(shot,source,weapon,spread):
  super.prepare_projectile(shot,source,weapon,spread)
  if not shot.get("prototype_missile",false):return
  counts["released_packets"]=counts.get("released_packets",0)+1
  released_payload+=float(shot.damage)
  var group=int(release_context.observed_group)
  groups[group].released+=1
  groups[group].ordinals.append(int(release_context.ordinal))
  groups[group].due.append(float(release_context.due))
  releases.append({"group":group,"time":motion_clock,"due":release_context.due,"ordinal":release_context.ordinal,"count":release_context.count,"damage":shot.damage,"target_uid":int(shot.target.get("uid",-1))})
 func hit_enemy(enemy,raw,type,effects=[],critical=false):
  var before=enemy.hp
  super.hit_enemy(enemy,raw,type,effects,critical)
  dealt+=float(N.subtract(before,N.maximum(0,enemy.hp)))
  raw_hit_payload+=float(raw)
  counts["hit"]=counts.get("hit",0)+1
  if before>0 and enemy.hp<=0:kills.append(motion_clock)
func _initialize():call_deferred("run")
func fixture(pattern:String,enemy_count:int,measurement:String)->Observed:
 var original=ShipDatabase.new()
 var g=Observed.new(original)
 assert(int(original.equipment.missile[0].para1)==4,"Original enemy/source table must stay unchanged")
 var row=g.db.equip("missile",150)
 assert(int(row.para1)==5 and is_equal_approx(float(row.cd),2.4),"Formal five-shot projection missing")
 g.stat_cache_enabled=true
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=30
 g.profile.enhancementAttacks=1000;g.profile.enhancementHits=1000
 g.profile.loadout={"weapons":[{"key":"missile","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 for node in pattern.length():
  if pattern[node] in ["A","B"]:assert(g.set_enhancement_branch("weapons","repeat",node+1,pattern[node]))
 g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true)
 g.enemies.clear()
 var base=float(g.equipment_stat("missile",150))
 var hp=base*1000*(1+g.enhancement_parameter("base_critical_rate")*(g.enhancement_parameter("base_critical_multiplier")+30*g.enhancement_parameter("critical_growth")-1)) if measurement=="ttk" else base*1e8
 for index in enemy_count:
  var target=template.duplicate(true)
  target.uid=100+index;target.slot=index;target.x=200+80*index;target.y=230-2*index
  assert(target.x>=0 and target.x<=BattleGame.BATTLE_SIZE.x and target.y>=0 and target.y<=BattleGame.BATTLE_SIZE.y)
  target.hp=hp;target.max_hp=hp;target.armourType=-99;target.equipment=[];target.cooldowns=[];target.drops=[]
  g.enemies.append(target)
 g.cooldowns[g.slot_id("weapons",0)]=0
 return g
func sample(pattern:String,enemy_count:int,measurement:String,seed_value:int)->Dictionary:
 var g=fixture(pattern,enemy_count,measurement)
 g.rng.seed=seed_value
 var limit=20 if measurement=="dps" else 60
 var elapsed=0.0
 for step in limit*60:
  g.tick(1.0/60.0);elapsed+=1.0/60.0
  if not g.has_alive_enemy():break
 assert(g.groups.values().all(func(group):return int(group.expected)==5 and int(group.committed)==5),"Every canonical/secondary salvo must commit five packets")
 for release in g.releases:
  assert(int(release.count)==5 and float(release.time)+.00000001>=float(release.due),"Actual queued ejection count/time mismatch")
 var complete_groups=0
 for group in g.groups.values():
  if int(group.released)==5:
   complete_groups+=1
   assert(group.ordinals==[0,1,2,3,4])
   for n in range(1,5):assert(absf(float(group.due[n])-float(group.due[n-1])-.28)<.0000001)
 return {"pattern":pattern,"seed":seed_value,"targets":enemy_count,"measurement":measurement,"seconds":elapsed,"actual_damage":g.dealt,"dps":g.dealt/elapsed,"wave_cleared":not g.has_alive_enemy(),"ttk":g.kills[-1] if not g.has_alive_enemy() and not g.kills.is_empty() else null,"kills":g.kills.size(),"counts":g.counts,"groups":g.groups.size(),"complete_released_groups":complete_groups,"queued_packets_remaining":g.missile_queue.size(),"queue_peak":g.queue_peak,"queued_payload":g.queued_payload,"released_payload":g.released_payload,"raw_hit_payload":g.raw_hit_payload,"launch_records":g.releases,"retirements":g.missile_retirements,"lifetime_expirations":g.lifetime_expirations,"orphan_expirations":g.orphan_expirations,"global_attacks_added":g.profile.enhancementAttacks-1000,"projected_weapon":{"para1":g.db.equip("missile",150).para1,"cd":g.db.equip("missile",150).cd,"base_damage":g.db.equip("missile",150).dmg},"body_remaining":g.player.armour+g.player.shield}
func output():
 var path=OS.get_environment("ENHANCEMENT_BENCH_OUTPUT")
 var f=FileAccess.open(path,FileAccess.WRITE)
 f.store_string(JSON.stringify({"runtime_commit":OS.get_environment("ENHANCEMENT_TESTED_COMMIT"),"runtime_class":"PresentedBattleGame","engine":Engine.get_version_info().string,"level":30,"module_level":150,"targets_geometry":[[200,230],[280,228],[360,226]],"provider":"default logical target/launch points; no renderer/GUI pose callbacks","rows":rows},"\t"))
func run():
 var started=Time.get_ticks_msec()
 var seeds=EXTRA_SEEDS if OS.get_environment("PRESENTED_SEEDS")=="extra" else SEEDS
 for target_count in [1,3]:
  for measurement in ["dps","ttk"]:
   for pattern in ["--A","--B","AAA","AAB"]:
    for seed_value in seeds:rows.append(sample(pattern,target_count,measurement,seed_value))
    output();print("PRESENTED_PROGRESS rows=",rows.size()," targets=",target_count," measurement=",measurement," elapsed=",(Time.get_ticks_msec()-started)/1000.0)
 output();quit()
