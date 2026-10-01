extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key:="laser"):
 var db=ShipDatabase.new()
 db.data.enhance_config.base_critical_rate.value=0
 db.data.enhance_config.repeat_probability.value=0
 for weapon in ["laser","longLaser"]:
  db.equipment[weapon][0].dmg=100;db.equipment[weapon][0].dmgMulti=0;db.equipment[weapon][0].cd=.2
 db.equipment.longLaser[0].para3=.2
 var g=BattleGame.new(db,false)
 g.speed=1;g.profile.cleared=range(1,41);g.rebuild_unlocks();g.profile.enhancementLevel=50
 g.profile.loadout={"weapons":[{"key":key,"level":150}],"defence":[{"key":"armour","level":150}]}
 g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e12;enemy.max_hp=1e12;enemy.armourType=0
 g.set_enhancement_branch("weapons","repeat",1,"B")
 return g
func payload(g):
 g.begin_enhancement_attack(0,g.enemies[0])
 var result=g.jewel_attack(0)
 g.finish_enhancement_attack(0)
 return result
func _initialize()->void:call_deferred("run")
func run()->void:
 var g=fixture()
 var primary=g.enemies[0];var target=g.enemies[1]
 for enemy in g.enemies:enemy.y=50.
 primary.x=100.;primary.y=100.;target.x=300.;target.y=100.
 var attack=payload(g);var hp=target.hp
 var fires=[];var impacts=[]
 g.event.connect(func(kind,info):
  if kind=="fire":fires.append(info)
  if kind=="projectile_impact":impacts.append(info))
 primary.hp=1
 g.hit_enemy(primary,attack.damage,1,attack.effects,true)
 check(g.projectiles.size()==1 and target.hp==hp,"killing hit launches one carrier without immediate chain damage")
 var hop=g.projectiles.back()
 check(Vector2(hop.x,hop.y)==Vector2(100,100) and fires.is_empty(),"chain starts at killed target, never fires from muzzle")
 check(hop.damage==attack.damage and hop.critical and hop.type==1,"raw payload and critical outcome inherited")
 g.advance_chain_projectile(hop,.1)
 check(target.hp==hp and not hop.dead,"partial flight cannot damage")
 target.armourType=1;g.db.config.dmgReduce=.5
 g.advance_chain_projectile(hop,.2)
 check(hop.dead and N.compare(target.hp,N.subtract(hp,N.ceiling(N.multiply(attack.damage,.5))))==0,"arrival reads current target resistance")
 var after=target.hp
 g.advance_chain_projectile(hop,1.)
 check(target.hp==after and impacts.size()==1 and g.projectiles.size()==1,"dead carrier cannot double-hit or recurse")
 g=fixture();primary=g.enemies[0];attack=payload(g)
 g.hit_enemy(primary,attack.damage,1,attack.effects)
 hop=g.projectiles.back();target=hop.target
 var heading=hop.direction;var position=Vector2(hop.x,hop.y)
 target.hp=0
 g.advance_chain_projectile(hop,.01)
 check(hop.target.is_empty() and hop.direction==heading and Vector2(hop.x,hop.y).distance_to(position+heading*7.2)<.001,"dead destination coasts on last heading")
 for i in 120:g.advance_chain_projectile(hop,1./60.)
 check(hop.dead,"orphan carrier leaves screen")
 g=fixture();g.db.data.enhance_config.repeat_b1_targets.value=2
 attack=payload(g);primary=g.enemies[0]
 var expected=g.targets(1).filter(func(e):return not is_same(e,primary)).slice(0,2)
 g.hit_enemy(primary,attack.damage,1,attack.effects)
 check(g.projectiles.size()==2,"alternate configured count fans out once")
 for i in 2:
  hop=g.projectiles[i]
  check(is_same(hop.target,expected[i]) and Vector2(hop.x,hop.y)==Vector2(primary.x,primary.y),"fanout preserves priority and common origin")
 var before=g.projectiles.map(func(p):return Vector2(p.x,p.y))
 g.paused=true;g.tick(.2)
 check(g.projectiles.map(func(p):return Vector2(p.x,p.y))==before,"pause freezes chain flight")
 g.paused=false
 for e in g.enemies:e.hp=0
 g.tick(0.)
 check(g.projectiles.size()==2,"ordinary wave preserves in-flight chain carriers")
 g.start(1,false)
 check(g.projectiles.is_empty(),"restart clears chain carriers")
 g.group_index=g.db.levels[0].groups.size()-1;g.spawn_group()
 for e in g.enemies:e.hp=1
 var sentinel={"dead":false,"chain_hop":true};g.projectiles.append(sentinel)
 for e in g.enemies:g.hit_enemy(e,1e20,0)
 check(g.projectiles.is_empty(),"final-group wipe clears chain carriers immediately")
 # Beam relation is selected once before charge, then damage follows each real tick.
 g=fixture("longLaser")
 var entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 var beam=g.projectiles.back();var chain=beam.attack_instance.chain
 target=chain.links[0].target;hp=target.hp
 var rng_state=g.rng.state;var history=g.profile.enhancementAttacks
 check(chain.links.size()==1 and beam.ticks==0,"beam binds configured relation at startup")
 g.tick_long_laser(beam,.1)
 check(target.hp==hp and beam.ticks==0,"charge alone cannot deal chain damage")
 g.tick_long_laser(beam,.1)
 check(target.hp<hp and beam.ticks==1 and g.projectiles.size()==1,"valid beam tick propagates without extra projectiles")
 after=target.hp
 g.tick_long_laser(beam,.4)
 check(target.hp<after and beam.ticks==3 and is_same(chain.links[0].target,target),"subsequent ticks retain startup relation")
 check(g.rng.state==rng_state and g.profile.enhancementAttacks==history,"beam cycles do not reroll or add attacks")
 target.hp=1;g.hit_enemy(target,1e20,0)
 target.hp=1e12
 g.tick_long_laser(beam,.2)
 check(chain.links[0].broken and target.hp==1e12 and g.beam_chain_targets(beam).is_empty(),"dead link stays broken even if same dictionary revives")
 beam.target.hp=0;var ticks=beam.ticks
 g.tick_long_laser(beam,.2)
 check(beam.dead and beam.ticks==ticks and chain.ended and chain.links.is_empty(),"primary interruption ends relation without damage")
 # Deterministic step partition and hostile path (legacy beam suite uses removed jewels).
 var stepped=fixture("longLaser");var batched=fixture("longLaser")
 for game in [stepped,batched]:
  var e=game.slot_entry("weapons",0)
  game.lock_long_laser(game.player,game.player_weapon_row(e),false,0,e)
 for i in 3:stepped.tick_long_laser(stepped.projectiles[0],.2)
 batched.tick_long_laser(batched.projectiles[0],.6)
 check(stepped.enemies.map(func(e):return e.hp)==batched.enemies.map(func(e):return e.hp),"beam and linked damage agree across step partitions")
 g=fixture("longLaser")
 var source=g.enemies[0]
 source.equipment=[{"name":"longLaser-mon"}]
 var weapon=g.player_weapon_row(g.slot_entry("weapons",0)).duplicate(true)
 g.lock_long_laser(source,weapon,true,0,source.equipment[0])
 beam=g.projectiles.back();g.tick_long_laser(beam,.1)
 check(beam.ticks==0,"hostile beam still charges")
 g.tick_long_laser(beam,.1)
 check(beam.ticks==1 and not beam.has("attack_instance"),"hostile beam tick needs no player chain instance")
 source.hp=0;g.tick_long_laser(beam,.2)
 check(beam.dead and beam.ticks==1,"hostile source death interrupts cleanly")
 print("CHAIN PROJECTILES: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
