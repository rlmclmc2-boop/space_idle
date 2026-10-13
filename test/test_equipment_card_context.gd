extends SceneTree
## Synthetic UI fixture; no player saves or progression run.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 var projections:=0
 func equipment_display_snapshot(entry:Dictionary,level:=-1)->Dictionary:
  if level<0:projections+=1
  return super.equipment_display_snapshot(entry,level)
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
 root.add_child(scene);scene.set_process(false);scene.beginner_guide.set_process(false)
 var g:BattleGame=scene.game
 g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.cleared=range(1,20);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.onboarding.completed=true;scene.beginner_guide.refresh()
 var panel=scene.equipment_panel
 for i in 3:
  var entry=g.module_entry("weapons",i);entry.key=["cannon","longLaser","laser"][i];entry.level=107
 g.invalidate_stat_cache();panel.refresh()
 await process_frame;await process_frame
 for i in 3:
  var entry=g.module_entry("weapons",i);var row=g.player_weapon_row(entry)
  var card=panel.cards["weapons_%d"%i];var label=card.fields.level
  check(label.text.contains(UIText.t("equipment.energy" if int(row.dmgtype)==1 else "equipment.physical")),"Card exposes authoritative damage type")
  check(label.text.contains(scene.number(float(row.cd))+"秒"),"Card exposes combat interval")
  check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"Context fits existing level line")
  check(card.custom_minimum_size==Vector2(310,176),"Card height is unchanged")
 check(panel.cards.weapons_1.fields.caption.text==UIText.t("weapon.card_beam_expected"),"Beam labels the individual expectation, not a volley total")
 panel.select_item("weapons_1");panel.show_inspector()
 check(panel.detail.basics.text.contains(UIText.t("equipment.attack_interval",{"seconds":scene.number(float(g.player_weapon_row(g.module_entry("weapons",1)).cd))})),"Inspector shares combat interval")
 var card=panel.cards.weapons_1;var damage=panel.items.weapons_1.mainStatNumber
 g.db.equipment.longLaser[0].cd=float(g.db.equipment.longLaser[0].cd)*0.8
 panel.invalidate_stats({"slot":"weapons_1","detail":true});panel.refresh_pending()
 check(panel.cards.weapons_1==card and card.fields.level.text.contains(scene.number(float(g.player_weapon_row(g.module_entry("weapons",1)).cd))+"秒"),"Interval-only update reuses card and refreshes context")
 check(GrowthNumber.compare(damage,panel.items.weapons_1.mainStatNumber)==0,"Interval context does not change damage")
 var defence=g.module_entry("defence",0)
 for key in ["armour","shield"]:
  defence.key=key;defence.level=107;g.invalidate_stat_cache();panel.refresh()
  var row=g.db.equip(key,107)
  check(panel.cards.defence_0.fields.level.text.contains("抗"+UIText.t("equipment.energy" if int(row.dmgtype)==1 else "equipment.physical")),"Defence shows its configured matching resistance")
 var reduction=g.db.config.dmgReduce;g.db.config.dmgReduce=0;panel.refresh()
 check(not panel.cards.defence_0.fields.level.text.contains("抗"),"Zero resistance is not labelled as protection against a type")
 g.db.config.dmgReduce=reduction;defence.key="";panel.refresh()
 check(not panel.cards.defence_0.fields.level.text.contains("抗"),"Empty defence has no resistance claim")
 g.module_entry("weapons",2).key="";panel.refresh()
 check(not panel.cards.weapons_2.fields.level.text.contains("秒") and not panel.cards.weapons_2.fields.stat.visible,"Empty slot has no attack context or damage")
 g.profile.loadout.weapons.append({"key":"cannon","level":107})
 check(not str(panel.equipment_item("weapons",3).cardLevelText).contains("秒"),"Inactive slot has no attack context")
 counter_refresh_case(scene,panel)
 print("Equipment card context: %d checks, %d failures"%[checks,failures])
 scene.queue_free();await process_frame;quit(1 if failures else 0)

func counter_refresh_case(scene,panel):
 var g=scene.game
 panel.detail_frame.hide()
 g.profile.loadout.weapons.resize(3)
 for i in 3:
  g.module_entry("weapons",i).assign({"key":"laser" if i<2 else "cannon","level":107})
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.enhancementLevel=40;g.profile.enhancementAttacks=100
 g.invalidate_stat_cache();panel.refresh()
 var card=panel.cards.weapons_0
 var context=card.fields.level.text;var skin=card.get_theme_stylebox("normal");var options=card.name_button
 var before=panel.items.weapons_0.projection.duplicate(true)
 g.profile.enhancementAttacks=1000000;g.invalidate_stat_cache()
 scene.projections=0
 panel.invalidate_stats({"category":"weapons","counter_only":true});panel.refresh_stats()
 check(scene.projections==2,"Equal entries share only this refresh's projection")
 check(before!=panel.items.weapons_0.projection,"Counter fixture changes displayed expectation")
 var incremental=panel.items.weapons_0.projection.duplicate(true)
 var value=card.fields.stat.text;var tooltip=card.tooltip_text
 check(card.fields.level.text==context and card.get_theme_stylebox("normal")==skin and card.name_button==options,"Counters preserve context, skin and option controls")
 panel.invalidate_stats({"category":"weapons"});panel.refresh_stats()
 check(panel.items.weapons_0.projection==incremental and card.fields.stat.text==value and card.tooltip_text==tooltip,"Immediate counter display equals full refresh")
 for full_first in [true,false]:
  for row in g.db.equipment.laser:row.cd=float(row.cd)*2.0
  g.invalidate_stat_cache()
  var full={"slot":"weapons_0","detail":true};var counter={"slot":"weapons_0","counter_only":true}
  panel.invalidate_stats(full if full_first else counter)
  panel.invalidate_stats(counter if full_first else full)
  check(panel.stats_dirty.weapons_0,"Full context invalidation wins either event order")
  panel.refresh_stats()
  check(card.fields.level.text!=context,"Coalesced full update refreshes interval")
  context=card.fields.level.text
 panel.hide();g.profile.enhancementAttacks=2000000;g.invalidate_stat_cache()
 panel.invalidate_stats({"category":"weapons","counter_only":true})
 check(panel.dirty,"Hidden counter update requests reveal refresh")
 panel.show();panel.refresh_pending()
 check(panel.items.weapons_0.projection==scene.equipment_display_snapshot(g.module_entry("weapons",0)),"Reveal catches up immediately")
