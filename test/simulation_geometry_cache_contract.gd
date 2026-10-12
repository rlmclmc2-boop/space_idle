extends SceneTree
# Regression: same dictionary identity and logical clock do not imply same pose.
class Probe extends "res://scripts/simulation_geometry_authority.gd":
 var source_pose={"logical_position":Vector2.ZERO,"target":Vector2(2,3),"phase":0.0,"born":0.0,"variance":1.0,"rotation":0.0,"duration":1.0,"entry_x":0.0}
 func enemy_pose(_enemy:Dictionary)->Dictionary:return source_pose
 func enemy_render_position(enemy:Dictionary)->Vector2:return source_pose.target+Vector2(enemy.x,enemy.y)
 func enemy_render_width_at_y(_enemy:Dictionary,_y:float)->float:return source_pose.variance
 func enemy_weapon_components(_enemy:Dictionary)->Array:return []
 func enemy_frontline_y_limit(_enemy:Dictionary)->float:return 100.0
 func display_shape(_enemy:Dictionary,_width:float)->String:return "fixture"
func _initialize()->void:
 var probe=Probe.new();var enemy={"uid":1,"x":0.0,"y":0.0}
 var first:Dictionary=probe.display_enemy(enemy)
 assert(is_same(first,probe.display_enemy(enemy)))
 probe.source_pose.rotation=0.7
 var rotated:Dictionary=probe.display_enemy(enemy)
 assert(not is_same(first,rotated) and rotated.angle==0.7 and first.angle==0.0)
 probe.source_pose.target=Vector2(8,9)
 assert(probe.display_enemy(enemy).position==Vector2(8,9))
 probe.source_pose.variance=2.0
 assert(probe.display_enemy(enemy).width==2.0)
 probe.source_pose.appearance={"signature":"changed"}
 var changed:Dictionary=probe.display_enemy(enemy)
 assert(not is_same(changed,rotated) and is_same(changed,probe.display_enemy(enemy)))
 assert(probe.display_row_builds==5)
 print("SIMULATION_GEOMETRY_CACHE_CONTRACT_PASS same_pose_same_clock_inplace_numeric_and_appearance_changes; stable_values_reused")
 quit()
