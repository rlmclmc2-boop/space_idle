extends SceneTree
# Compare buffer ownership and caps with the exact pre-change validation.
class Reference extends BattleGame:
 func sync_enhancement_buffers() -> void:
  for index in enhancement_buffers.keys():
   var entry := slot_entry("defence",int(index))
   var owner: Dictionary=enhancement_buffer_owners.get(index,{})
   var effect := memory_effect(entry)
   if entry.is_empty() or effect.is_empty() or not is_same(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):
    enhancement_buffers.erase(index)
    enhancement_buffer_owners.erase(index)
   else:
    var capacity = enhancement_module_protection_capacity(int(index)) if stat_cache_enabled else N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry))
    enhancement_buffers[index]=N.minimum(enhancement_buffers[index],capacity)
var checks := 0
var failures := 0
func fixture(reference: bool, cached: bool, level: int, position: int, owner_case: int) -> BattleGame:
 var g: BattleGame=Reference.new(ShipDatabase.new(),false) if reference else BattleGame.new(ShipDatabase.new(),false)
 g.profile.hightechSavedAt=1701.0
 g.profile.cleared=range(1,101);g.rebuild_unlocks()
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.enhancementLevel=level
 g.profile.loadout={"weapons":[],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 var order: Array=["adaptation","delayed_damage"]
 order.insert(position,"memory_material");g.profile.enhancementOrder.defence=order
 g.stat_cache_enabled=cached;g.invalidate_stat_cache();g.reset_player()
 for index in g.defense_entries().size():
  var entry=g.slot_entry("defence",index)
  g.enhancement_buffers[index]=g.N.multiply(g.enhancement_module_protection_capacity(index),2)
  g.enhancement_buffer_owners[index]={"entry":entry if owner_case!=1 else entry.duplicate(),"key":str(entry.key) if owner_case!=2 else "wrong"}
 return g
func _initialize() -> void:
 for cached in [false,true]:
  for level in [0,9,10,19,20,30,60]:
   for position in 3:
    for owner_case in 3:
     var a=fixture(true,cached,level,position,owner_case)
     var b=fixture(false,cached,level,position,owner_case)
     var before_a=a.player.duplicate(true);var before_b=b.player.duplicate(true)
     a.sync_enhancement_buffers();b.sync_enhancement_buffers()
     checks+=1
     if a.enhancement_buffers!=b.enhancement_buffers or a.enhancement_buffer_owners!=b.enhancement_buffer_owners or a.player!=before_a or b.player!=before_b:
      failures+=1;printerr("FAIL membership cached=",cached," level=",level," order=",position," owner=",owner_case)
 print("MEMORY BUFFER MEMBERSHIP: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
