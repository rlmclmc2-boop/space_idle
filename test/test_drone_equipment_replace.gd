extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
var changes:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func unchanged(g,before:Dictionary)->bool:return g.profile==before
func _initialize()->void:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g=BattleGame.new(db,false);g.profile.highestLevel=200;g.profile.cleared=range(1,200);g.rebuild_unlocks();g.pending_unlocks.clear()
 var h=g.hyperspace;var rng=RandomNumberGenerator.new();rng.seed=12345
 for i in 6:
  var d=Rewards.create_drone(rng,h.config,"replace-%d"%i,"blue","laser",5,"1")
  check(Bag.insert(g.profile.hyperspace.inventory,d,h.config),"valid owned fixture %d"%i)
 var single:="";var multi:=""
 for key in h.config.hull_capacities:
  if int(h.config.hull_capacities[key])==1:single=key
  elif int(h.config.hull_capacities[key])==2:multi=key
 check(not single.is_empty() and not multi.is_empty(),"production hulls offer one and two slots")
 if single!=str(g.profile.selectedShip):check(g.switch_ship(single),"select single-slot hull")
 g.event.connect(func(kind,info):
  if kind=="hyperspace_changed" and info.reason=="equipment_changed":changes+=1)
 var r:Dictionary=h.equip_drone(g,"replace-0")
 check(r.ok and r.changed and r.capacity==1 and r.equipped==["replace-0"],"equip empty single slot")
 g.combat_weapon_entries();g.hyperspace_totals()
 var old_changes:=changes;r=h.equip_drone(g,"replace-1")
 check(r.ok and r.replaced_id=="replace-0" and r.equipped==["replace-1"] and changes==old_changes+1,"single-slot replacement publishes once")
 check(g.combat_weapon_entries().any(func(e):return e.get("drone_id")=="replace-1") and not g.combat_weapon_entries().any(func(e):return e.get("drone_id")=="replace-0"),"combat source changes immediately after cached read")
 check(g.hyperspace_totals()==g.DroneEffects.project(g),"effect projection refreshed immediately")
 var before:Dictionary=g.profile.duplicate(true);old_changes=changes;r=h.equip_drone(g,"replace-1")
 check(r.ok and not r.changed and r.reason=="already_equipped" and unchanged(g,before) and changes==old_changes,"repeated equip is idempotent")
 r=h.equip_drone(g,"missing")
 check(not r.ok and r.reason=="unknown_drone" and unchanged(g,before),"unknown candidate leaves original installed")
 g.profile.hyperspace.inventory.sealed["replace-2"]=1;before=g.profile.duplicate(true);r=h.equip_drone(g,"replace-2")
 check(not r.ok and r.reason=="sealed" and unchanged(g,before),"sealed candidate does not unequip original")
 g.profile.hyperspace.inventory.sealed.erase("replace-2")
 g.profile.hyperspace.inventory.warehouse.erase("replace-2");g.profile.hyperspace.inventory.overflow.append("replace-2");before=g.profile.duplicate(true);r=h.equip_drone(g,"replace-2")
 check(not r.ok and r.reason=="not_in_warehouse" and unchanged(g,before),"overflow candidate rejected atomically")
 g.profile.hyperspace.inventory.overflow.erase("replace-2");g.profile.hyperspace.inventory.warehouse.append("replace-2")
 check(g.switch_ship(multi),"switch to production two-slot hull")
 r=h.equip_drone(g,"replace-2");check(r.ok and r.capacity==2 and r.equipped==["replace-1","replace-2"],"multi-slot appends into free slot")
 before=g.profile.duplicate(true);r=h.equip_drone(g,"replace-3")
 check(not r.ok and r.reason=="select_replacement" and unchanged(g,before),"full multi-slot requires explicit target; cancel needs no mutation")
 r=h.equip_drone(g,"replace-3","missing");check(not r.ok and r.reason=="replacement_not_equipped" and unchanged(g,before),"stale target rejected without loss")
 r=h.equip_drone(g,"replace-3","replace-2");check(r.ok and r.equipped==["replace-1","replace-3"] and r.replaced_id=="replace-2","explicit target preserves slot order and other occupant")
 before=g.profile.duplicate(true);r=h.equip_drone(g,"replace-3","replace-2");check(r.ok and not r.changed and unchanged(g,before),"duplicate confirmed replacement does not toggle off")
 check(g.switch_ship(single) and g.profile.hyperspace.inventory.equipped==["replace-1"],"smaller hull fits actual capacity")
 r=h.equip_drone(g,"replace-4");check(r.ok and r.capacity==1 and r.equipped==["replace-4"],"subsequent request uses new hull capacity")
 var saved:Dictionary=g.portable_save_data();var prepared:Dictionary=Transfer.new().prepare_data(saved,db)
 check(prepared.error=="","replacement loadout remains export-valid")
 var restored=BattleGame.new(db,false);restored.load_progress_data(saved)
 check(restored.profile.hyperspace.inventory.equipped==["replace-4"] and restored.profile.selectedShip==single,"save restore retains replaced slot and hull")
 r=restored.hyperspace.unequip_drone(restored,"replace-4");check(r.ok and r.changed and r.equipped.is_empty(),"explicit unequip")
 before=restored.profile.duplicate(true);r=restored.hyperspace.unequip_drone(restored,"replace-4");check(r.ok and not r.changed and unchanged(restored,before),"repeated unequip is idempotent")
 var wide:=""
 for key in h.config.hull_capacities:
  if int(h.config.hull_capacities[key])>=3:wide=key
 check(not wide.is_empty() and g.switch_ship(wide),"production larger hull")
 var legend_ids:Array=[]
 for i in 3:
  var d=Rewards.create_drone(rng,h.config,"legend-%d"%i,"legendary","laser",5,"1")
  check(Bag.insert(g.profile.hyperspace.inventory,d,h.config),"valid legendary fixture %d"%i);legend_ids.append(d.id)
 check(h.set_equipped(g,[legend_ids[0],legend_ids[1],"replace-0"]),"legal legendary budget with replaceable ordinary slot")
 before=g.profile.duplicate(true);old_changes=changes;r=h.equip_drone(g,legend_ids[2],"replace-0")
 check(not r.ok and r.reason=="legendary_limit" and unchanged(g,before) and changes==old_changes,"rejected final legendary budget preserves all original occupants")
 print("DRONE REPLACEMENT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
