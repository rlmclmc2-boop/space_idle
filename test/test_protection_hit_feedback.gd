extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class FeedbackUI extends "res://scripts/main.gd":
 func fast_mode_enabled() -> bool:return false
 func player_art_scale() -> float:return 1.0
 func player_render_position() -> Vector2:return Vector2(200,600)
 func battle_logical_point(point: Vector2) -> Vector2:return point
 func flush_damage_numbers() -> void:pass
var checks:=0
var failures:=0
var rows: Array=[]
var baseline:=OS.get_environment("PROTECTION_FEEDBACK_BASELINE")=="1"
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(lab := false) -> BattleGame:
 var db:=ShipDatabase.new()
 for key in ["shield","armour"]:
  var row: Dictionary=db.equipment[key][0].duplicate(true)
  row.para1=100;row.para2=0;row.para3=0;row.para4=0
  db.equipment[key]=[row]
 db.config.dmgReduce=.5
 var g: BattleGame=load("res://scripts/balance_game.gd").new(db) if lab else BattleGame.new(db,false)
 g.rng.seed=1701;g.speed=1
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=1
 g.profile.enhancementOrder.defence=["memory_material","adaptation","delayed_damage"]
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"shield","level":1},{"key":"armour","level":1}]}
 g.reset_player()
 g.advance_jewel_repair(2)
 g.enhancement_buffers.clear()
 return g
func capture(g: BattleGame) -> Array:
 var events: Array=[]
 g.event.connect(func(kind: String,payload: Dictionary):
  if kind=="hit" and payload.player:events.append(payload.duplicate(true)))
 return events
func report(g: BattleGame,events: Array,label: String,loss,absorbed):
 var quiet_deferred: bool=baseline and label in ["deferred_full","debt_tick_full"]
 check(events.size()==(0 if quiet_deferred else 1),label+" produces expected feedback event")
 var info: Dictionary={"x":g.player.x,"y":g.player.y,"amount":0,"player":true,"type":0} if quiet_deferred else events.back()
 check(N.compare(info.amount,loss)==0,label+" preserves immediate body loss")
 if not baseline:check(N.compare(info.get("absorbed",0),absorbed)==0,label+" reports actual protection consumption")
 var ui:=FeedbackUI.new();ui.game=g
 if not quiet_deferred:ui.queue_damage_number(info)
 var text: String="no_event" if quiet_deferred else ui.damage_pending.back().text
 if not baseline:
  check(text.contains("吸收")== (N.compare(absorbed,0)>0),label+" absorption label matches consumed protection")
  if N.compare(absorbed,0)>0 and N.compare(loss,0)==0:check(not text.begins_with("0"),label+" full absorption is not shown as zero damage")
  check(ui.damage_history.back().contains(ui.call("damage_feedback_text",loss,absorbed,true)),label+" history distinguishes absorption from body loss")
 rows.append({"case":label,"body":info.amount,"absorbed":info.get("absorbed",0),"text":text,"history":ui.damage_history.back() if not quiet_deferred else "no_event","shield":g.player.shield,"armour":g.player.armour,"buffers":g.enhancement_buffers.duplicate(true),"cover":g.enhancement_branches.defense(g,0).cover,"hits":g.profile.enhancementHits,"rng":str(g.rng.state),"debt":g.enhancement_deferred.duplicate(true),"module_damage":g.jewel_defence_damage.duplicate(true),"state":g.state,"since_hit":g.since_hit})
 ui.free()
func _initialize():call_deferred("run")
func run():
 var g=fixture();var events=capture(g)
 g.enhancement_branches.defense(g,0).cover=30
 g.hit_player(20,1);report(g,events,"cover_all",0,20)
 check(g.player.shield==100 and g.player.armour==100 and g.enhancement_branches.defense(g,0).cover==10,"Full cover is actually consumed without body loss")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0}
 g.hit_player(10,1);report(g,events,"buffer_all",0,10)
 check(g.enhancement_protection_current()==10,"Full buffer absorption consumes only ten")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.enhancement_branches.defense(g,0).cover=5
 g.hit_player(30,1);report(g,events,"cover_buffer_partial",3,25)
 check(g.enhancement_protection_current()==0 and g.player.shield==97,"Only surviving raw overflow receives body resistance and rounding")
 events.clear();g.hit_player(20,1);report(g,events,"after_exhaustion",10,0)
 check(g.player.shield==87,"Exhausted temporary layers do not block next damage")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.enhancement_branches.defense(g,0).cover=5
 g.hit_player(0,1);report(g,events,"true_zero",0,0)
 check(g.enhancement_protection_current()==20 and g.enhancement_branches.defense(g,0).cover==5,"Zero input consumes no temporary protection")
 for resistance in [.5,1.0]:
  g=fixture();events=capture(g);g.profile.enhancementLevel=50
  check(g.set_enhancement_branch("defence","memory_material",2,"B"),"Memory resistance fixture eligible")
  g.db.data.enhance_config.memory_b2_resistance.value=resistance
  g.enhancement_buffers={0:10.0,1:10.0}
  g.hit_player(10,1);report(g,events,"resistance_"+str(resistance),0,5 if resistance==.5 else 0)
  check(g.enhancement_protection_current()==(15 if resistance==.5 else 20),"Resistance feedback counts pool spending, not mitigated raw")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.enhancement_branches.defense(g,0).cover=5
 g.hit_player(250,1);report(g,events,"overflow_to_armour",125,25)
 check(g.player.shield==0 and g.player.armour==75,"Protection and shield overflow still charge correct armour loss")
 g=fixture(true);events=capture(g);g.metrics=load("res://scripts/balance_metrics.gd").new();g.enhancement_buffers={0:10.0,1:10.0}
 g.hit_player(10,1);report(g,events,"lab_metrics_absorbed",0,10)
 check(g.metrics.received==0 and g.metrics.health_lost==0 and g.metrics.shield_absorbed==0,"Lab body-loss metrics never count temporary absorption as lost health or typed shield")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.state=BattleGame.State.COMBAT;g.spawn_group()
 var enemy: Dictionary=g.enemies[0]
 g.fire(enemy,g.player,g.db.equip("laser",1),10,true,"laser-mon")
 g.projectiles.back().x=g.player.x;g.projectiles.back().y=g.player.y
 g.tick_projectiles(0);report(g,events,"ordinary_projectile",0,10)
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.state=BattleGame.State.COMBAT;g.spawn_group()
 enemy=g.enemies[0];enemy.equipment=[{"name":"longLaser-mon"}];enemy.dmgMultiple=1.0
 g.db.equipment["longLaser-mon"]=[{"name":"longLaser-mon","level":1,"dmg":10,"dmgtype":1,"cd":.2,"para1":1.0,"para2":1.0,"para3":0.0,"unlock":0}]
 g.lock_long_laser(enemy,g.db.enemy_weapon("longLaser-mon"),true,0,enemy.equipment[0])
 g.tick_long_laser(g.projectiles.back(),0);report(g,events,"continuous_beam",0,10)
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0}
 g.apply_enhancement_deferred("armour",10);report(g,events,"deferred_full",0,10)
 check(g.enhancement_protection_current()==10 and g.profile.enhancementHits==0,"Deferred absorption pays protection without an incoming hit count")
 g=fixture();events=capture(g);g.enhancement_buffers={0:10.0,1:10.0};g.enhancement_branches.defense(g,0).cover=5
 g.apply_enhancement_deferred("armour",30);report(g,events,"deferred_partial",5,25)
 check(g.player.shield==95 and g.player.armour==100 and g.profile.enhancementHits==0,"Deferred remainder uses current shield without new resistance or incoming count")
 events.clear();g.apply_enhancement_deferred("shield",0)
 check(events.is_empty(),"Zero debt payment emits no damage or absorption feedback")
 if not baseline:
  var ui:=FeedbackUI.new();ui.game=g
  ui.queue_damage_number({"amount":0,"absorbed":10,"player":true,"type":1})
  ui.queue_damage_number({"amount":3,"absorbed":5,"player":true,"type":1})
  check(ui.damage_pending.size()==1 and ui.damage_pending[0].amount==3 and ui.damage_pending[0].absorbed==15,"Coalescing keeps body loss and absorption separate")
  check(ui.damage_pending[0].text=="3 · 吸收 15","Merged label does not report absorption as body loss")
  ui.free()
 # These positive fractions must survive both the floating label and history.
 for value in [.04,.01,.001]:
  g=fixture();events=capture(g);g.enhancement_branches.defense(g,0).cover=value
  g.hit_player(value,0);report(g,events,"fraction_cover_"+str(value),0,value)
  if not baseline:
   var fractional_ui:=FeedbackUI.new();fractional_ui.game=g
   fractional_ui.queue_damage_number(events.back())
   check(fractional_ui.damage_pending.back().text=="吸收 "+str(value),"Floating fraction is nonzero: "+str(value))
   check(fractional_ui.damage_history.back().contains("吸收 "+str(value)),"History fraction is nonzero: "+str(value))
   fractional_ui.free()
 g=fixture();events=capture(g);g.enhancement_buffers={0:.001}
 g.hit_player(.001,0);report(g,events,"fraction_buffer",0,.001)
 if not baseline:check(rows.back().history.contains("吸收 0.001"),"Fractional buffer spending is nonzero in history")
 for raw in [1e16,{"m":1.0,"e":400.0}]:
  for delayed in [false,true]:
   g=fixture();events=capture(g);g.enhancement_branches.defense(g,0).cover=1
   if delayed:g.apply_enhancement_deferred("shield",raw)
   else:g.hit_player(raw,0)
   report(g,events,("huge_deferred_" if delayed else "huge_incoming_")+str(raw),200,1)
   check(g.enhancement_branches.defense(g,0).cover==0,"Large hit spends the unit cover")
 # A real incoming hit creates nonempty debt, then scheduled payments consume
 # fractional cover without a second incoming hit or altered RNG rolls.
 g=fixture();g.profile.enhancementOrder.defence=["delayed_damage","adaptation","memory_material"]
 g.db.data.enhance_config.deferred_clear_probability.value=0
 g.reset_player();g.enhancement_buffers.clear();g.state=BattleGame.State.COMBAT;events=capture(g)
 g.hit_player(.8,0);report(g,events,"debt_source",.4,0)
 check(not g.enhancement_deferred.is_empty() and is_equal_approx(float(g.enhancement_deferred_total()),.4),"Real fractional hit creates its deferred debt")
 var expected_rng:=RandomNumberGenerator.new();expected_rng.state=g.rng.state
 expected_rng.randf()
 g.enhancement_branches.defense(g,0).cover=.04
 events.clear();g.advance_enhancement_deferred_tick();report(g,events,"debt_tick_full",0,.04)
 if not baseline:check(rows.back().history.contains("吸收 0.04"),"Scheduled full absorption keeps its positive fraction in history")
 check(is_equal_approx(float(g.enhancement_deferred_total()),.36) and g.enhancement_deferred.size()>0,"Covered scheduled payment consumes only its due bucket")
 check(is_equal_approx(g.player.shield,99.6) and g.profile.enhancementHits==1 and g.rng.state==expected_rng.state,"Covered debt preserves body, incoming count and the one clearance roll")
 expected_rng.randf()
 g.enhancement_branches.defense(g,0).cover=.01;g.enhancement_buffers.clear()
 events.clear();g.advance_enhancement_deferred_tick();report(g,events,"debt_tick_partial",1,.01)
 if not baseline:check(rows.back().history.contains("吸收 0.01"),"Scheduled partial absorption keeps its positive fraction in history")
 check(is_equal_approx(g.player.shield,99.57) and is_equal_approx(float(g.enhancement_deferred_total()),.32),"Partial scheduled absorption leaves exactly the fractional body payment and remaining debt")
 check(g.profile.enhancementHits==1 and g.rng.state==expected_rng.state,"Partial debt does not recount hits or add RNG rolls")
 FileAccess.open("res://feedback-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
 print("PROTECTION FEEDBACK: %d checks, %d failures; baseline=%s speed=1" % [checks,failures,baseline])
 quit(1 if failures else 0)
