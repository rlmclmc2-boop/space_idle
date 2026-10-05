extends "res://scripts/battlefield.gd"
## QA-only exact pose memoization, owned by this scene and one logical pose boundary.
var pose_epoch:Array=[]
var pose_results:Dictionary={}
func enemy_render_position(enemy:Dictionary)->Vector2:
 var epoch:Array=[fx_time,game.state,game.stage,game.group_index,str(game.profile.selectedShip)]
 if epoch!=pose_epoch:pose_epoch=epoch;pose_results.clear()
 var uid:int=int(enemy.uid)
 var old:Dictionary=pose_results.get(uid,{})
 var point:=Vector2(enemy.x,enemy.y)
 if not old.is_empty() and is_same(old.entity,enemy) and old.logical==point:return old.position
 var result:Vector2=super.enemy_render_position(enemy)
 pose_results[uid]={"entity":enemy,"logical":point,"position":result}
 return result
func on_event(kind:String,info:Dictionary)->void:
 if kind in ["state","encounter","module_changed","ship_changed","upgrade","upgrades_completed","jewels_changed","planet_reforged"]:pose_results.clear();pose_epoch=[]
 super.on_event(kind,info)
