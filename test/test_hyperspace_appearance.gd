extends SceneTree
const Appearance=preload("res://scripts/hyperspace_appearance.gd")
const Visual=preload("res://scripts/hyperspace_drone_visual.gd")
class PoseView extends Node:
 const WORLD_PER_PIXEL=0.05
 var rendered_position=Vector2(280,700)
 var size=Vector2(550,900)
 var orbit_elapsed=0.0
var checks=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):checks.append({"ok":ok,"label":label});print("CHECK ",ok," ",label)
func run():
 var bag={"equipped":[],"drones":{},"generation":1}
 for n in 5:
  var id="fixture:"+str(n);bag.equipped.append(id)
  bag.drones[id]={"id":id,"weapon":["laser","missile","cannon","longLaser","missile"][n],"origin_quality":"white","legendary":false,"ultimate":false,"ultimate_affix":{},"affixes":[{"key":"damage","tier":4,"value":0.1}]}
 var raw={"save":{"hyperspace":{"inventory":bag.duplicate(true)}}};var before=bag.duplicate(true)
 var v=Visual.new();root.add_child(v);v.sync(bag)
 var ids={};var sockets={};var socket_positions={}
 for id in v.members:ids[id]=v.members[id].get_instance_id();sockets[id]=v.muzzles[id][0].get_instance_id();socket_positions[id]=v.muzzles[id][0].global_position
 var creations=v.model_creations;var projections=Appearance.projections;var resources=Appearance.resource_creations
 for n in 1000:v.sync(bag)
 check(v.model_creations==creations and Appearance.projections==projections and Appearance.resource_creations==resources,"1000 stable syncs create no models/resources and aggregate no affixes")
 var id=str(bag.equipped[0]);bag.drones[id].legendary=true;bag.drones[id].ultimate=true;bag.drones[id].origin_quality="blue";bag.drones[id].affixes=[{"key":"chain_count","tier":1,"value":99}];bag.generation+=1
 var style=Appearance.project(bag.drones[id]);v.sync(bag)
 check(style.quality=="legendary" and style.ultimate and style.tier==1 and style.category=="chain","blue-origin legendary plus ultimate and strongest T1 are independent")
 check(bag.drones[id].origin_quality=="blue","appearance preserves blue module origin")
 check(v.model_creations==creations and v.members[id].get_instance_id()==ids[id],"same-ID modernization retains original model")
 check(v.muzzles[id][0].get_instance_id()==sockets[id] and v.muzzles[id][0].global_position==socket_positions[id],"same-ID modernization retains original authored muzzle and launch position")
 check(v.members.keys().all(func(x):return v.members[x].get_instance_id()==ids[x]),"all unrelated models retain instances")
 check(v.style_updates==6,"only changed drone style updated")
 var restored=bag.drones[id].duplicate(true);restored.ultimate=false;restored.affixes=[{"key":"attack_speed","tier":4,"value":0.01}];restored.ultimate_affix={"key":"damage","tier":1,"value":1}
 check(Appearance.project(restored).category.is_empty(),"restored ultimate affix never activates T1 cosmetic")
 var t1=bag.drones[id].duplicate(true);t1.affixes=[{"key":"attack_speed","tier":5},{"key":"armour_capacity","tier":2},{"key":"damage","tier":1}]
 check(Appearance.project(t1).tier==1 and Appearance.project(t1).category=="attack","effective min tier wins irrespective of affix order")
 var common=t1.duplicate(true);common.ultimate=false;common.ultimate_affix={};common.affixes=[{"key":"damage","tier":4}];var key4=Appearance.fingerprint(Appearance.project(common));common.affixes[0].tier=5
 check(Appearance.fingerprint(Appearance.project(common))==key4,"T4/T5 do not cause visually irrelevant rebuilds")
 var icon_style=Appearance.project(bag.drones[id]);var bake_start=Time.get_ticks_usec();var texture=Appearance.thumbnail(icon_style);var cold_thumbnail_us=Time.get_ticks_usec()-bake_start;var count=Appearance.resource_creations
 for n in 100:
  var d=bag.drones[id].duplicate(true);d.id="random-"+str(n);d.affixes[0].value=n
  var same=Appearance.thumbnail(Appearance.project(d))==texture
  if n==99:check(same,"cache identity ignores drone ID and random values")
 check(Appearance.resource_creations==count,"random ID and rolled values add no thumbnail resources")
 var variant_start=Time.get_ticks_usec()
 for n in 70:
  var variant=bag.drones[id].duplicate(true);variant.weapon=["laser","missile","cannon","longLaser"][n%4];variant.origin_quality=["white","blue","gold","legendary"][int(n/4)%4];variant.legendary=variant.origin_quality=="legendary";variant.ultimate=int(n/16)%2==1;variant.ultimate_affix={};variant.affixes=[{"key":"damage" if n<64 else "chain_count","tier":int(n/32)%2+1}]
  Appearance.thumbnail(Appearance.project(variant))
 var variants_70_us=Time.get_ticks_usec()-variant_start
 check(Appearance.thumbnail_cache.size()==64 and Appearance.thumbnail_order.size()==64,"70 distinct appearances evict thumbnails at hard capacity64")
 check(texture!=null and texture.get_width()==192,"eviction preserves live control texture references")
 var removed=str(bag.equipped[1]);var replacement="visual-only-new";bag.drones[replacement]=bag.drones[removed].duplicate(true);bag.drones[replacement].id=replacement;bag.equipped[1]=replacement;bag.generation+=1;v.sync(bag)
 check(v.model_creations==creations+1 and not v.members.has(removed) and v.members.size()==5,"one equip replacement creates only one new model")
 check(v.members[id].get_instance_id()==ids[id] and v.muzzles[id][0].get_instance_id()==sockets[id],"equip replacement preserves unaffected model and socket")
 check(raw.save.hyperspace.inventory==before,"source fixture unchanged by cosmetic projection")
 # Dummy top-down view uses the production pose, including complete ancestor visibility.
 var view=PoseView.new();root.add_child(view);v.pose(view,[id]);check(not v.members[id].visible and not v.members[id].get_node("Appearance").is_visible_in_tree(),"disabled parent hides all ornaments and ultimate ring")
 v.pose(view,[]);check(v.members[id].visible,"reenabled drone restores visibility")
 var orbit=v.members[id].get_node("Appearance/UltimateOrbit");view.orbit_elapsed=2;v.pose(view,[]);check(is_equal_approx(orbit.rotation.y,0.9),"ultimate visual orbit uses existing presentation clock")
 v.animated=false;view.orbit_elapsed=3;v.pose(view,[]);check(is_equal_approx(orbit.rotation.y,0.9),"accelerated mode freezes orbit animation")
 var stable_resources=Appearance.resource_creations
 for n in 100:view.orbit_elapsed+=0.01;v.pose(view,[])
 check(Appearance.resource_creations==stable_resources,"pose animation creates no mesh material or texture resources")
 var failures=checks.filter(func(c):return not c.ok)
 if not OS.get_environment("HYPERSPACE_VISUAL_EVIDENCE").is_empty():
  FileAccess.open(OS.get_environment("HYPERSPACE_VISUAL_EVIDENCE"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"model_creations":v.model_creations,"style_updates":v.style_updates,"appearance_projections":Appearance.projections,"resource_creations":Appearance.resource_creations,"cold_thumbnail_us":cold_thumbnail_us,"distinct_thumbnails_70_us":variants_70_us},"\t"))
 print("VISUAL_REGRESSION failures=",failures.size());v.free();view.free();quit(failures.size())
