extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
var rows: Array=[]
const PROPERTIES={"player_cannon_speed_multiplier":"RAIL_SPEED_FACTOR","missile_ejection_gap":"EJECTION_GAP","missile_launch_speed":"MISSILE_LAUNCH_SPEED","missile_turn_rate":"MISSILE_TURN_RATE","missile_orphan_lifetime":"ORPHAN_LIFETIME","missile_reacquire_interval":"MISSILE_REACQUIRE_INTERVAL","missile_departure_angle":"MISSILE_DEPARTURE_ANGLE","missile_ignition_at":"MISSILE_IGNITION","missile_seek_start":"MISSILE_SEEK_START","missile_cruise_at":"MISSILE_CRUISE_AT","missile_lifetime":"MISSILE_LIFETIME","missile_brake_range":"MISSILE_BRAKE_RANGE","missile_brake_angle":"MISSILE_BRAKE_ANGLE","missile_min_guided_speed":"MISSILE_MIN_GUIDED_SPEED","missile_brake_factor":"MISSILE_BRAKE_FACTOR","missile_hit_radius":"MISSILE_HIT_RADIUS","missile_launch_edge_margin":"MISSILE_LAUNCH_EDGE_MARGIN","missile_launch_forward_y":"MISSILE_LAUNCH_FORWARD_Y"}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(variant:Dictionary={},level:=1):
 var db:=ShipDatabase.new()
 if variant.get("_legacy",false):
  db.data.erase("weapon_motion");db.data.erase("enemy_weapon_base")
 for section in ["equipment","weapon_motion","enemy_weapon_base","defaults"]:
  if variant.has(section):db.data[section]=variant[section].duplicate(true)
 db.equipment=db.data.equipment;db.defaults=db.data.defaults
 var g=Presented.new(db,false);g.rng.seed=1701;g.speed=1
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.loadout={"weapons":[{"key":"missile","level":level}],"defence":[{"key":"shield","level":1},{"key":"armour","level":1}]}
 g.reset_player();g.start(1,false);g.spawn_group()
 var enemy:Dictionary=g.enemies[0].duplicate(true);enemy.uid=1701;enemy.hp=1e100;enemy.max_hp=1e100;enemy.x=300;enemy.y=100;enemy.cooldowns=enemy.cooldowns.map(func(_v):return 999.0)
 g.enemies.clear();g.enemies.append(enemy);g.refresh_missile_target_registry()
 g.launch_provider=func(_mount,_aim,_ordinal):return {"position":Vector2(300,700),"direction":Vector2.UP}
 g.cooldowns.weapons_0=999.0
 return g
func salvo(g):
 var weapon=g.player_weapon_row(g.slot_entry("weapons",0));g.begin_enhancement_attack(0,g.enemies[0]);g.record_enhancement_attack()
 for i in int(weapon.para1):g.jewel_fire(0,g.enemies[0],weapon,Vector2.ZERO,1,0,i,int(weapon.para1))
 g.finish_enhancement_attack(0)
func enemy_values(g):
 var result={}
 for key in ["laser_mon","laser-mon","missile_mon","missile-mon","cannon_mon","cannon-mon","longLaser_mon","longLaser-mon"]:
  var row=g.db.enemy_weapon(key);var values={}
  for field in ["dmg","cd","dmgtype","para1","para2","para3"]:values[field]=row.get(field)
  result[key]=values
 return result
func fallback_values(g, null_fields := false):
 var source=g.db.enemy_source
 var result={}
 for base in ["laser","missile","cannon","longLaser"]:
  var key:String=base+"-mon"
  var saved=source.equipment.get(key)
  if null_fields:
   source.equipment[key]=[{"name":key,"level":1,"dmg":null,"cd":null,"dmgtype":null,"para1":null,"para2":null,"para3":null}]
  else:source.equipment.erase(key)
  var row=g.db.enemy_weapon(key);var values={}
  for field in ["dmg","cd","dmgtype","para1","para2","para3"]:values[field]=row.get(field)
  result[base]=values
  if saved==null:source.equipment.erase(key)
  else:source.equipment[key]=saved
 return result
func _initialize():call_deferred("run")
func run():
 var g=fixture();var default_enemy=enemy_values(g);var default_fallback=fallback_values(g);var growth=[]
 for level in [1,2,50,150,10000]:growth.append(g.db.equip("missile",level).dmg)
 salvo(g)
 var packets=g.missile_queue.map(func(p):return {"due":p.due,"damage":p.attack.damage,"critical":p.attack.critical,"ordinal":p.ordinal})
 for i in 240:g.tick(1.0/60.0)
 var default_state={"growth":growth,"packets":packets,"launches":g.launch_records,"hits":g.hit_records,"enemy_hp":g.enemies[0].hp if not g.enemies.is_empty() else 0,"rng":str(g.rng.state),"attacks":g.profile.enhancementAttacks,"incoming":g.profile.enhancementHits,"cooldown":g.cooldowns.weapons_0,"enemy":default_enemy,"fallback":default_fallback,"null_fields":fallback_values(g,true)}
 FileAccess.open("res://weapon-default-results.json",FileAccess.WRITE).store_string(JSON.stringify(default_state))
 check(packets.size()==5 and g.launch_records.size()==5,"Default source fires current five-carrier salvo")
 check(g.db.equip("missile",1).dmg==120 and g.db.equip("missile",1).cd==2.4,"Default damage and cooldown match current presentation")
 if OS.get_environment("WEAPON_CONFIG_BASELINE")!="1":
  var source:=ShipDatabase.new();var legacy_equipment:Dictionary=source.equipment.duplicate(true)
  for field in ["dmg","cd","dmgtype","para1","para2","para3"]:legacy_equipment.missile[0][field]=source.data.enemy_weapon_base.missile[field]
  var legacy_defaults:Dictionary=source.defaults.duplicate(true);legacy_defaults.projectilePixelsPerUnit=28.0
  var legacy=fixture({"_legacy":true,"equipment":legacy_equipment,"defaults":legacy_defaults})
  check(legacy.db.equip("missile",1).dmg==120 and legacy.db.equip("missile",1).cd==2.4 and legacy.db.equip("missile",1).para1==5,"Legacy JSON without migration sections retains former presented missile values")
  check(enemy_values(legacy)==default_enemy,"Legacy data fallback preserves hostile weapon values")
  check(legacy.MISSILE_CRUISE_SPEED==420 and legacy.EJECTION_GAP==.28 and legacy.RAIL_SPEED_FACTOR==12,"Legacy missing motion data uses former presentation defaults")
 if OS.get_environment("WEAPON_CONFIG_BASELINE")!="1":
  var scan=load("res://scripts/balance_scan.gd")
  var data=ShipDatabase.new().data
  check(not scan.parameters(data).has(["weapon_motion","missile_turn_rate","value"]),"Lab catalog omits formal presentation-only guidance parameters")
  check(not scan.parameters(data).has(["defaults","projectilePixelsPerUnit"]),"Retired runtime pixel default is absent from current scan catalog")
  for actor in ["player","enemy"]:
   var path=["weapon_motion",actor+"_projectile_pixels_per_unit","value"]
   check(scan.parameters(data).has(path) and not scan.valid_value(path,0) and scan.valid_value(path,28),"Scan discovers and validates active "+actor+" speed source")
  check(scan.valid_value(["weapon_motion","missile_launch_forward_y","value"],-.2) and not scan.valid_value(["weapon_motion","missile_launch_forward_y","value"],.2),"Scan recognizes authored forward-direction domain")
 if FileAccess.file_exists("res://weapon-config-variants.json") and OS.get_environment("WEAPON_CONFIG_BASELINE")!="1":
  var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://weapon-config-variants.json"))
  for variant in cases:
   g=fixture(variant)
   var key:String=variant.id;var label:String=variant.section+"."+key+"."+variant.field
   if variant.section=="equipment":
    check(g.db.equip(key,1).get(variant.field)==variant.value,label+" is not overwritten after Excel export")
   elif PROPERTIES.has(key):check(is_equal_approx(float(g.get(PROPERTIES[key])),float(variant.value)),label+" reaches active motion property")
   if key in ["player_projectile_pixels_per_unit","enemy_projectile_pixels_per_unit"]:
    check(float(g.db.call("projectile_pixels_per_unit",key=="enemy_projectile_pixels_per_unit"))==variant.value,label+" selects actor-specific exported unit scale")
   if key!="enemy_projectile_pixels_per_unit":
    check(enemy_values(g)==default_enemy,label+" leaves explicit hostile numbers unchanged")
    check(fallback_values(g)==default_fallback and fallback_values(g,true)==default_fallback,label+" isolates hostile missing-row and null-field fallbacks")
   salvo(g);var count:int=g.missile_queue.size()
   check(count==int(g.db.equip("missile",1).para1),label+" emitted batch obeys authored quantity")
   if count>1:check(is_equal_approx(g.missile_queue[1].due-g.missile_queue[0].due,g.EJECTION_GAP),label+" uses authored ejection cadence")
   var payload=g.missile_queue[0].attack.damage
   if variant.section=="equipment" and key=="missile":
    var expected=g.equipment_stat("missile",1)
    if g.missile_queue[0].attack.critical:expected=N.multiply(expected,g.jewel_critical(g.slot_entry("weapons",0)).y)
    check(N.compare(payload,expected)==0,label+" actual damage carrier inherits the authored base and unchanged crit")
    if variant.field=="dmgMulti":check(g.db.equip("missile",50).dmg==g.db.equipment_combat_growth(120,.15,50),label+" new growth affects target-level damage")
   g.tick_projectiles(0);var shot:Dictionary=g.projectiles.back()
   check(shot.speed==g.MISSILE_LAUNCH_SPEED and shot.cruise_speed==float(g.db.equip("missile",1).para2)*float(g.db.call("projectile_pixels_per_unit",false)),label+" launch and cruise come from exported values")
   if key=="missile_departure_angle":check(is_equal_approx(absf(Vector2.UP.angle_to(shot.direction)),deg_to_rad(float(variant.value))),label+" actual tube departure uses authored angle")
   var age:=float(g.MISSILE_CRUISE_AT);g.advance_custom_projectile(shot,age)
   check(is_equal_approx(shot.speed,shot.cruise_speed),label+" actual flight reaches authored cruise speed")
   if key=="missile_turn_rate":
    shot.motion_age=1.0;shot.x=300;shot.y=700;shot.direction=Vector2.RIGHT;shot.target.x=300;shot.target.y=100
    g.advance_custom_projectile(shot,.1)
    check(is_equal_approx(absf(Vector2.RIGHT.angle_to(shot.direction)),float(variant.value)*.1),label+" actual steering uses configured turn bound")
   if key=="missile_lifetime":
    shot.motion_age=variant.value+.01;shot.dead=false;g.advance_custom_projectile(shot,0)
    check(shot.dead and g.lifetime_expirations==1,label+" actual live lock expires at configured lifetime")
   if key=="missile_orphan_lifetime":
    shot.target={};shot.orphan_age=variant.value-.01;shot.dead=false;g.advance_custom_projectile(shot,.02)
    check(shot.dead and g.orphan_expirations==1,label+" actual orphan expires at configured backstop")
   if key in ["missile_brake_range","missile_brake_angle","missile_min_guided_speed","missile_brake_factor"]:
    var distance:=10.0 if key=="missile_min_guided_speed" else 100.0
    var angle:=.25 if key=="missile_brake_angle" else PI/2
    shot.motion_age=1.0;shot.dead=false;shot.x=300;shot.y=100+distance;shot.direction=Vector2.UP.rotated(angle)
    g.advance_custom_projectile(shot,0)
    var speed:float=shot.cruise_speed if key=="missile_brake_range" else maxf(g.MISSILE_MIN_GUIDED_SPEED,distance*g.MISSILE_TURN_RATE*g.MISSILE_BRAKE_FACTOR)
    check(is_equal_approx(shot.speed,speed),label+" actual proximity brake branch changes with the exported threshold")
   if key=="missile_hit_radius":
    shot.motion_age=1.0;shot.dead=false;shot.x=300;shot.y=106;shot.direction=Vector2.UP
    g.advance_custom_projectile(shot,0)
    check(shot.dead and g.hit_records.size()==1,label+" actual collision uses expanded radius")
   if key in ["missile_ignition_at","missile_seek_start","missile_cruise_at"]:
    shot.motion_age=0;shot.dead=false;shot.x=300;shot.y=700;shot.direction=Vector2.RIGHT if key=="missile_seek_start" else Vector2.UP
    g.advance_custom_projectile(shot,.3 if key=="missile_seek_start" else .15 if key=="missile_ignition_at" else .7)
    if key=="missile_ignition_at":check(shot.speed>g.MISSILE_LAUNCH_SPEED,label+" actual acceleration starts at new ignition time")
    elif key=="missile_seek_start":check(not shot.direction.is_equal_approx(Vector2.RIGHT),label+" actual guidance begins at new seek time")
    else:check(shot.speed<shot.cruise_speed,label+" actual acceleration remains below cruise at new ramp time")
   if key=="missile_reacquire_interval":
    g.motion_clock=0;g.missile_target_candidates.clear();g.missile_target_scans=0
    g.missile_retarget_candidate(2);g.motion_clock=.18;g.missile_retarget_candidate(2)
    check(g.missile_target_scans==1,label+" actual pending-target cache uses new interval")
   if key in ["missile_launch_edge_margin","missile_launch_forward_y"]:
    var direction:Vector2=Vector2.from_angle(deg_to_rad(-150)) if key=="missile_launch_edge_margin" else Vector2.from_angle(-PI+asin(.15)+deg_to_rad(g.MISSILE_DEPARTURE_ANGLE))
    g.launch_provider=func(_mount,_aim,_ordinal):return {"position":Vector2(60 if key=="missile_launch_edge_margin" else 300,700),"direction":direction}
    salvo(g);g.tick_projectiles(0)
    check(g.projectiles.back().direction.is_equal_approx(direction),label+" actual departure safety gate reads authored threshold")
   if variant.section=="equipment" and key=="missile" and variant.field=="cd":
    g.cooldowns.weapons_0=0;g.tick(.01)
    check(is_equal_approx(g.cooldowns.weapons_0,variant.value),label+" actual X1 firing resets cooldown to authored interval")
   if key=="chain_carrier_speed":
    var target:Dictionary=g.enemies[0].duplicate(true);target.uid=1702;target.x=500;g.enemies.append(target)
    g.launch_enhancement_chain(g.enemies[0],5,2,[{"chain":true,"chain_targets":1}],false)
    var hop:Dictionary=g.projectiles.back();var start:=Vector2(hop.x,hop.y)
    check(hop.get("chain_hop",false) and hop.speed==variant.value,label+" actual chain carrier uses authored speed")
    g.advance_chain_projectile(hop,.1)
    check(is_equal_approx(start.distance_to(Vector2(hop.x,hop.y)),variant.value*.1),label+" actual chain movement follows authored speed")
   g.fire(g.player,g.enemies[0],g.db.equip("cannon",1),1,false,"cannon")
   var cannon_speed=g.projectiles.back().speed
   check(cannon_speed==float(g.db.equip("cannon",1).para1)*float(g.db.call("projectile_pixels_per_unit",false))*g.RAIL_SPEED_FACTOR,label+" actual player cannon uses table multiplier")
   g.fire(g.enemies[0],g.player,g.db.enemy_weapon("cannon-mon"),1,true,"cannon-mon")
   check(g.projectiles.back().speed==float(g.db.enemy_weapon("cannon-mon").para1)*float(g.db.call("projectile_pixels_per_unit",true)),label+" hostile cannon remains isolated")
   rows.append({"case":label,"quantity":count,"payload":payload,"launch":g.MISSILE_LAUNCH_SPEED,"cruise":shot.cruise_speed,"cannon_speed":cannon_speed,"enemy_speed":g.projectiles.back().speed})
  FileAccess.open("res://weapon-mutation-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
 print("WEAPON CONFIG: %d checks, %d failures; speed=1; mutation_cases=%d" % [checks,failures,rows.size()])
 quit(1 if failures else 0)
