extends SceneTree
# Focused coverage for synchronous UI quotes and protection read projections.
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func show_qa_tools() -> void:pass
 func show_chrono_login_report() -> void:pass
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func verify_quotes(scene) -> void:
 var g=scene.game
 var panel=scene.equipment_panel
 var before=JSON.stringify(g.profile)
 var rng_before=g.rng.state
 panel.refresh_affordability()
 for item in panel.items.values():
  if item.locked:
   check(item.cost=="—" and not item.direct_upgradeable,"Dormant module stays disabled")
   continue
  var count=g.max_upgrade_amount_slot(item.category,item.index) if panel.upgrade_amount==0 else panel.upgrade_amount
  check(item.cost==scene.cost_text(g.slot_upgrade_cost(item.category,item.index,maxi(1,count))),"Quote matches original price: "+item.id)
  check(item.direct_upgradeable==(count>0 and g.can_upgrade_slot(item.category,item.index,count)),"Affordability matches original rules: "+item.id)
 check(before==JSON.stringify(g.profile) and rng_before==g.rng.state,"UI quotes never mutate progress or RNG")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game
 g.stat_cache_enabled=true;g.save_enabled=false;g.paused=true
 g.profile.cleared=range(1,101);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.enhancementLevel=30
 g.profile.loadout={"weapons":[{"key":"laser","level":150},{"key":"missile","level":150},{"key":"cannon","level":151},{"key":"longLaser","level":151},{"key":"","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150},{"key":"shield","level":151},{"key":"armour","level":151},{"key":"armour","level":150}]}
 g.invalidate_stat_cache();g.reset_player();scene.refresh_structure();scene.select_system(0)
 var panel=scene.equipment_panel
 for amount in [1,10,0]:
  panel.set_upgrade_amount(amount)
  for balance in [0.0,1e14,1e20]:
   g.profile.resources={"1":balance,"2":balance}
   verify_quotes(scene)
 # A config edit and an actual purchase must be reflected by the very next pass.
 g.db.equipment.laser[0].cost_1*=1.37
 verify_quotes(scene)
 check(g.upgrade_slot("weapons",0,1),"Purchase succeeds through original transaction")
 panel.refresh();verify_quotes(scene)
 var ids=panel.cards.duplicate()
 scene.select_system(2);g.profile.resources={"1":0.0,"2":0.0};scene.select_system(0)
 panel.refresh_pending();verify_quotes(scene)
 check(ids==panel.cards,"Hide/reveal preserves module controls")
 g.paused=false
 for step in 4:
  g.advance_jewel_repair(0.5)
  if step==2:g.hit_player(100,1)
  var before=JSON.stringify(g.profile);var rng_before=g.rng.state
  var status=g.enhancement_protection_status()
  check(status.current==g.enhancement_protection_current() and status.capacity==g.enhancement_protection_capacity(),"Status agrees with canonical pool after repair/hit")
  var current=0.0;var capacity=0.0
  for component in status.components:
   check(component.current==g.enhancement_visible_buffer(component.index) and component.capacity==g.enhancement_module_protection_capacity(component.index),"Module projection agrees with independent reads")
   current=GrowthNumber.add(current,component.current);capacity=GrowthNumber.add(capacity,component.capacity)
  check(current==status.current and capacity==status.capacity,"Components sum to the displayed pool")
  check(before==JSON.stringify(g.profile) and rng_before==g.rng.state,"Protection reads preserve progress and RNG")
 var light=scene.ship_view.world.get_node("KeyLight")
 check(light.shadow_enabled and light.directional_shadow_mode==DirectionalLight3D.SHADOW_ORTHOGONAL,"Live shadows remain enabled for the orthographic battlefield")
 print("Performance projections: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
