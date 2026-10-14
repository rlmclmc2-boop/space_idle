extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Visual=preload("res://scripts/hyperspace_drone_visual.gd")
var checks:=0
var failures:=0
class Baker extends RefCounted:
 func guard_resolution(_value:float)->void:pass
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture():
 var g=BattleGame.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks();g.stat_cache_enabled=true
 var rng=RandomNumberGenerator.new();rng.seed=12
 var d=Rewards.create_drone(rng,g.hyperspace.config,"rebuild","legendary","laser",5,"1")
 var parameters:Dictionary={}
 for key in g.hyperspace.config.legendary_effects.drone_rebuild.parameters:parameters[key]=float(g.hyperspace.config.legendary_effects.drone_rebuild.parameters[key][1])
 d.legendary_effect={"effect_id":"drone_rebuild","parameters":parameters};d.affixes=[]
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 check(g.hyperspace.set_equipped(g,[d.id]),"equip actual rebuild legendary")
 g.state=g.State.COMBAT;g.group_index=1;g.enemies.assign([{"uid":10,"hp":100.0}])
 return g
func consume(g)->void:
 g.player.armour=0
 check(g.drone_combat.try_rebuild(g),"actual lethal reconstruction activates")
 check(g.drone_combat.disabled==["rebuild"] and g.drone_combat.rebuild_stacks==1 and g.drone_combat.rebuild_bonus>0,"cost and temporary bonus active together")
 check(g.combat_weapon_entries().size()==g.weapon_entries().size(),"disabled drone cannot fire")
func visual_visible(g)->bool:
 var visual=Visual.new();var body=Node3D.new();visual.nodes.append(body);visual.identities.append("rebuild");visual.body_bake_pending=false
 var view={"body_baker":Baker.new(),"viewport":{"size":Vector2i(100,100),"scaling_3d_scale":1.0},"camera":{"size":100.0}}
 visual.apply_geometry_frame(view,{"drones":{"rebuild":Transform3D.IDENTITY}},g.drone_combat.disabled)
 var visible=body.visible;body.free();visual.free();return visible
func restored(g,label:String)->void:
 check(g.drone_combat.disabled.is_empty() and g.drone_combat.rebuild_stacks==0 and g.drone_combat.rebuild_bonus==0,label+" expires exactly reconstruction state")
 check(g.combat_weapon_entries().size()==g.weapon_entries().size()+1,label+" restores firing eligibility")
 check(visual_visible(g),label+" production visual visibility restored")
func _initialize()->void:call_deferred("run")
func run()->void:
 var g=fixture();consume(g)
 check(not visual_visible(g),"production visual hidden during cost")
 g.finish_combat_step(0.0)
 check(g.drone_combat.disabled==["rebuild"] and g.drone_combat.rebuild_stacks==1,"live encounter cannot restore early")
 g.player.armour=23;g.player.shield=7
 g.drone_combat.delayed=[{"remaining":2.0}];g.drone_combat.dodge_cooldown=3;g.drone_combat.black_hole_elapsed=4;g.drone_combat.black_hole_remaining=5;g.drone_combat.black_hole_damage=6;g.drone_combat.missile_attacks=7
 var events:Array=[]
 g.event.connect(func(kind,info):
  if kind=="hyperspace_rebuild" and info.get("restored",false):events.append(info))
 g.enemies[0].hp=0;g.finish_combat_step(0.0);restored(g,"ordinary encounter")
 check(g.state==g.State.TRAVEL and g.player.armour==23 and g.player.shield==7,"travel recovery does not heal or refill")
 check(g.drone_combat.delayed==[{"remaining":2.0}] and g.drone_combat.dodge_cooldown==3 and g.drone_combat.black_hole_elapsed==4 and g.drone_combat.black_hole_remaining==5 and g.drone_combat.black_hole_damage==6 and g.drone_combat.missile_attacks==7,"other legendary state untouched")
 g.drone_combat.restore_rebuild(g);check(events.size()==1,"restoration event emitted exactly once")
 g=fixture();consume(g);g.profile.loop=true;g.profile.guardStage=g.stage;g.profile.guardDistance=g.distance;g.guard_arrived=true;g.guard_index=0;g.guard_engaged=true;g.enemies[0].hp=0
 g.finish_combat_step(0.0);restored(g,"guard waiting")
 check(g.state==g.State.COMBAT,"guard waiting does not require state change")
 g.respawn_guard();restored(g,"guard respawn")
 g=fixture();consume(g);g.group_index=g.db.levels[g.stage-1].groups.size();g.enemies[0].hp=0
 g.finish_combat_step(0.0);restored(g,"final encounter")
 check(g.state==g.State.LEVEL_CLEAR,"final encounter clears level")
 g=fixture();consume(g);g.player.armour=0;g.player.shield=0;g.begin_retreat();restored(g,"death")
 check(g.state==g.State.RETREAT and g.player.armour==0 and g.player.shield==0,"death restore is not resurrection or shield refill")
 g=fixture();g.enemies.clear();g.state=g.State.MAIN_MENU;g.group_index=0;var routes:Dictionary={};var number=9000;var mon=int(g.db.enemies.keys()[0])
 for route in ["alpha","beta","gamma","delta"]:
  routes[route]=[]
  for layer in 10:
   number+=1;routes[route].append(number);g.db.groups[str(number)]={"slots":[mon],"combatTier":"normal" if layer<4 else "elite" if layer<8 else "boss" if layer==8 else "ultimate","formation_positions":[[150.0,150.0]]}
 check(g.configure_hyperspace_routes(routes) and g.start_hyperspace("alpha",g.hyperspace.current_layer(g,"alpha")+1),"actual manual session starts")
 g.spawn_group();consume(g);g.player.armour=0;g.player.shield=0;g.begin_retreat()
 check(not g.manual_hyperspace.active and g.manual_hyperspace.last_result.get("reason","")=="defeat","manual defeat exits through existing return flow")
 restored(g,"manual death return")
 g=fixture()
 g.rng.seed=711;var baseline=g.jewel_attack(0);consume(g)
 g.rng.seed=711;var boosted=g.jewel_attack(0);var old_damage=boosted.damage
 check(GrowthNumber.compare(boosted.damage,baseline.damage)>0,"future attack during reconstruction uses its temporary bonus")
 var saved_attack=boosted.duplicate(true)
 g.drone_combat.restore_rebuild(g)
 g.rng.seed=711;var next_attack=g.jewel_attack(0)
 check(GrowthNumber.compare(next_attack.damage,baseline.damage)==0,"future births after restore discard reconstruction bonus")
 check(boosted==saved_attack and GrowthNumber.compare(boosted.damage,old_damage)==0,"already-born attack payload remains immutable across restore")
 check(next_attack.main_attack_id!=boosted.main_attack_id,"future attack has its own birth identity")
 var compiler=preload("res://scripts/native_execution_compiler.gd").new()
 check(compiler.compile(g,"native_low_contract").get("error","")=="unsupported_legendary:drone_rebuild","unsupported reconstruction remains on existing GDScript owner")
 print("DRONE_REBUILD_BOUNDARY ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
