extends SceneTree
## Shared rank boundaries, dormant choices, same-schema persistence and clickable details.
const N=preload("res://scripts/growth_number.gd")
class IsolatedUI extends "res://scripts/main.gd":
 var writes: Array=[]
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
 func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
  if control.get(property)!=value:writes.append(control)
  super.set_ui_value(control,property,value)
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture() -> BattleGame:
 var db:=ShipDatabase.new()
 for key in ["laser","cannon"]:
  db.equipment[key][0].dmg=100;db.equipment[key][0].dmgMulti=0;db.equipment[key][0].cri=0;db.equipment[key][0].criDmg=0
 db.equipment.armour[0].para1=100;db.equipment.armour[0].para2=0
 var g:=BattleGame.new(db,false)
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels"),db.unlock_id("ship","Heavy_Battleship")]
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"armour","level":1}]}
 g.profile.resources={"1":1e28,"2":1e28}
 g.reset_player()
 return g
func click(control: Control) -> void:
 if DisplayServer.get_name()=="headless":
  control.pressed.emit();await process_frame;return
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event)
  await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g:=fixture()
 for level in [0,9,10,19,20]:
  g.profile.enhancementLevel=level
  var expected:=1 if level<10 else 2 if level<20 else 3
  for key in ["laser","armour"]:
   for equipment_level in [1,200]:
    var entry={"key":key,"level":equipment_level}
    check(g.available_effect_count(entry)==expected and g.active_enhancement_effect_count(entry)==expected and g.enhancement_effects(entry).size()==expected,"Shared level%s independent of equipment%s/%s"%[level,key,equipment_level])
 for category in ["weapons","defence"]:
  var order: Array=g.enhancement_order(category)
  for rank in 3:
   for node in [1,2,3]:
    var gate: int=rank*10+node*10
    check(g.enhancement_branch_threshold(node,category,order[rank])==gate,"Position branch gate%s/%s/%s"%[category,rank,node])
    for level in [gate-1,gate]:
     g.profile.enhancementLevel=level
     check(g.enhancement_branch_unlocked(category,order[rank],node)==(level==gate),"Position branch boundary%s/%s/%s/%s"%[category,rank,node,level])
 # A distinct valid configuration drives all consumers, including zero-first semantics.
 for i in 3:g.db.data.enhance_config["threshold_%d"%(i+1)].value=[0,7,17][i]
 for i in 3:g.db.data.enhance_config["branch_threshold_%d"%(i+1)].value=[5,11,23][i]
 g.profile.enhancementLevel=7
 check(g.active_enhancement_effect_count(g.slot_entry("weapons",0))==2 and g.enhancement_branch_threshold(2,"weapons","critical")==28,"Alternative shared/node config is authoritative")
 g=fixture();g.profile.enhancementLevel=0
 check(g.set_enhancement_order("weapons",["repeat","proficiency","critical"]) and g.has_enhancement_effect(g.slot_entry("weapons",0),"repeat"),"Unopened effect can swap into first position at shared zero")
 g.db.data.enhance_config.repeat_probability.value=1;g.db.data.enhance_config.base_critical_rate.value=0
 g.state=BattleGame.State.COMBAT;g.spawn_group()
 g.begin_enhancement_attack(0,g.enemies[0]);g.record_enhancement_attack()
 g.jewel_fire(0,g.enemies[0],g.player_weapon_row(g.slot_entry("weapons",0)),g.player_weapon_offset(0))
 g.queue_jewel_repeats(0,1);g.finish_enhancement_attack(0);g.advance_jewel_repeats(g.enhancement_parameter("repeat_delay"))
 check(g.projectiles.size()==2 and g.projectiles[0].damage==g.projectiles[1].damage and g.profile.enhancementAttacks==2,"Shared-zero repeat actually launches unchanged100% extra damage and counts its batch")
 g=fixture();g.profile.enhancementLevel=0
 check(g.set_enhancement_order("weapons",["critical","repeat","proficiency"]),"Critical swaps into active first position")
 g.profile.enhancementLevel=10;g.invalidate_stat_cache()
 check(g.set_enhancement_branch("weapons","critical",1,"A"),"Branch A opens at rank1 shared10")
 check(is_equal_approx(g.jewel_critical(g.slot_entry("weapons",0)).x,.4),"Active A branch affects actual critical rate")
 g.set_enhancement_order("weapons",["proficiency","repeat","critical"])
 check(g.enhancement_branch_choice("weapons","critical",1)=="A" and not g.enhancement_branch_unlocked("weapons","critical",1) and is_equal_approx(g.jewel_critical(g.slot_entry("weapons",0)).x,.25),"Reorder retains choice but immediately deactivates below new gate")
 g.profile.enhancementLevel=30;g.invalidate_stat_cache()
 check(g.enhancement_branch_unlocked("weapons","critical",1) and is_equal_approx(g.jewel_critical(g.slot_entry("weapons",0)).x,.4),"Retained choice resumes at moved rank gate")
 g.profile.enhancementLevel=10;g.profile.jewelFragments=12345;g.profile.enhancementAttacks=987;g.profile.enhancementHits=654
 g.save_enabled=true;g.save_progress()
 var restored:=BattleGame.new(g.db,true)
 check(restored.enhancement_order("weapons")==["proficiency","repeat","critical"] and restored.enhancement_branch_choice("weapons","critical",1)=="A" and not restored.enhancement_branch_unlocked("weapons","critical",1),"Same-schema save retains order and dormant kind-owned branch")
 check(restored.enhancement_level()==10 and restored.profile.jewelFragments==12345 and restored.profile.enhancementAttacks==987 and restored.profile.enhancementHits==654,"No split levels, refunds or history migration")
 g.save_enabled=false
 g.equip_slot("weapons",0,"cannon");g.upgrade_slot("weapons",0);g.reset_player()
 check(g.profile.enhancementAttacks==987 and g.profile.enhancementHits==654,"Refit upgrade and ordinary reset preserve global histories")
 g.profile.enhancementLevel=9;g.profile.planets["1"].conquered=true;g.invalidate_stat_cache()
 check(g.active_enhancement_effect_count(g.slot_entry("weapons",0))==2 and g.enhancement_cost()==g.enhancement_parameter("cost_base")*pow(g.enhancement_parameter("cost_growth"),9),"Permanent bonus counts toward shared gate without changing purchased cost")
 var locked:=BattleGame.new(g.db,false)
 locked.profile.enhancementLevel=50
 check(locked.active_enhancement_effect_count({"key":"laser","level":200})==0 and locked.enhancement_effects({"key":"laser","level":200}).is_empty(),"Overall feature unlock still gates effects")
 # Repair is per module and only overflow fills protection; delayed100% clear still pays first.
 g=fixture();g.profile.enhancementLevel=1;g.set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
 g.player.armour=75;g.sync_jewel_defence_damage();g.advance_jewel_repair(.2)
 check(g.player.armour==76 and g.memory_buffer(0)==0,"Memory repairs module loss before overflow")
 g.player.armour=100;g.sync_jewel_defence_damage();g.advance_jewel_repair(.2)
 check(g.memory_buffer(0)==1 and g.enhancement_module_protection_capacity(0)==10,"Memory percentages use own module maximum")
 g=fixture();g.profile.enhancementLevel=1;g.set_enhancement_order("defence",["delayed_damage","adaptation","memory_material"])
 g.db.config.dmgReduce=0;g.db.data.enhance_config.deferred_clear_probability.value=1
 g.state=BattleGame.State.COMBAT;g.hit_player(20,0);g.advance_jewel_repair(.2)
 check(g.player.armour==89 and g.enhancement_deferred.is_empty() and g.profile.enhancementHits==1,"Certain clear pays first global-aligned installment without recounting hit")
 # The six ordinary cards stay mounted; details open even below their effect gate.
 var scene:=IsolatedUI.new();scene.automation_args=["--capture"];root.add_child(scene)
 scene.music.stop();scene.music.stream=null
 scene.set_process(false);scene.game.save_enabled=false;scene.game.paused=true
 scene.game.profile.cleared=range(1,61);scene.game.profile.highestLevel=61;scene.game.rebuild_unlocks();scene.game.pending_unlocks.clear()
 scene.game.profile.onboarding.completed=true;scene.game.profile.enhancementLevel=0
 scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate();scene.game.switch_ship("Heavy_Battleship")
 scene.game.equip_slot("weapons",0,"laser");scene.game.equip_slot("defence",0,"armour")
 scene.refresh_tab_visibility();scene.select_system(4)
 await process_frame;await process_frame
 var panel: Control=scene.enhancement_panel
 var cards: Array=[]
 for category in ["weapons","defence"]:
  for rank in 3:
   var card: Dictionary=panel.effect_cards[category][rank];cards.append(card.panel)
   check(card.up.disabled==(rank==0) and card.down.disabled==(rank==2) and not card.details.disabled,"Unopened card retains reorder and explicit details%s/%s"%[category,rank])
   await click(card.details)
   check(panel.effect_detail_dialog.visible and panel.effect_detail_dialog.title==card.title.text and not panel.effect_detail_body.text.contains("{") and not panel.effect_detail_body.text.contains("[enhance."),"Clickable configured details%s/%s"%[category,rank])
   if DisplayServer.get_name()!="headless" and category=="defence" and rank==2:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../shared-enhancement-details.png")
   panel.effect_detail_dialog.hide()
 check(panel.eligible_count("weapons",0)>0 and panel.eligible_count("weapons",1)==0,"UI counts use same shared-zero authority")
 panel.move_effect("weapons",2,-1);panel.move_effect("weapons",1,-1)
 check(scene.game.enhancement_order("weapons")[0]=="critical" and panel.eligible_count("weapons",0)>0 and scene.game.has_enhancement_effect(scene.game.slot_entry("weapons",0),"critical"),"UI reorder immediately updates actual eligible effect")
 panel.open_branches("weapons","critical")
 check(panel.branch_rows[0].title.text==UIText.t("enhance.branches.milestone",{"node":1,"level":10}) and panel.branch_rows[0].A.disabled,"Drawer uses current position gate at shared0")
 scene.game.profile.enhancementLevel=10;scene.game.invalidate_stat_cache();panel.refresh()
 check(not panel.branch_rows[0].A.disabled and panel.branch_rows[1].A.disabled,"Existing drawer catches up at shared10")
 panel.branch_overlay.hide()
 scene.writes.clear();panel.refresh()
 check(scene.writes.is_empty(),"Paused unchanged enhancement refresh writes no properties")
 for i in 3:check(is_same(cards[i],panel.effect_cards.weapons[i].panel),"Reorder retains persistent card%s"%i)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../shared-enhancement-overview.png")
 scene.music.stop();scene.music.stream=null
 scene.queue_free();await process_frame
 await process_frame
 print("SHARED ENHANCEMENT RANKS: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
