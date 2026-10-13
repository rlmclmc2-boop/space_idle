extends SceneTree
const Layout=preload("res://scripts/enemy_fixed_layout.gd")
class Game extends RefCounted:
	var enemies:Array=[]
	func is_final_encounter():return false
class Host extends RefCounted:
	var game=Game.new()
	var db={"config":{}}
	var SHIP_VISUALS={"CANVAS":Vector2(572,960)}
	var SHIP_ART_CANVAS=Vector2(572,960)
	var BATTLE_VIEW_SIZE=Vector2(572,960)
	var fixed_layout_revision=0
	var fixed_layout_signature:Array=[]
	var fx_time=4.0
	var screen_scale=0.6
	var model_scale=1.0
	var battle_visual={"enemy_depth_scale_max":1.12,"enemy_scale_variance":Vector2(.9,1.08),"enemy_base_scale":.34,"player_core_scale":.65,"player_idle_rotation":.7,"player_ship_y":.91,"player_idle_y":3.,"enemy_player_min_gap":.2,"enemy_max_y":.36,"enemy_entry_distance":50.,"enemy_idle_y":7.,"enemy_idle_x":8.}
	func player_base_art_scale():return .18
	func player_art_scale():return .18
	func enemy_config_visual_scale(_s):return model_scale
	func enemy_recognition_screen_scale():return screen_scale
func _initialize():
	var h=Host.new();var checks=0;var rows=[]
	for scale in [.43,.6,.8]:
		h.screen_scale=scale
		for model_scale in [1.,1.4,2.]:
			h.model_scale=model_scale;h.game.enemies.clear();var poses=[]
			for i in 15:
				var y=[110.,270.,350.][i/5]
				var e={"uid":i,"slot":i,"size":4,"x":100.+(i%5)*90.,"y":y,"size_formation":true,"explicit_formation":false,"formation_columns":5,"formation_count":15}
				h.game.enemies.append(e)
				poses.append({"target":Vector2(e.x,y+smoothstep(220.,420.,y)*220.),"logical_position":Vector2(e.x,y),"phase":0.,"born":0.,"duration":1.,"entry_x":0.,"variance":1.})
			Layout.sync(h);var points=[]
			for i in [0,5,10]:points.append(Layout.position(h,h.game.enemies[i],poses[i]))
			assert(absf(points[0].y-(110.+sin(4.*.91)*7.*.25))<.001)
			assert(points[1].y-points[0].y>180. and points[2].y-points[1].y>180.)
			assert(absf((points[1].y-points[0].y)-(points[2].y-points[1].y))<20.)
			checks+=3;rows.append({"screen_scale":scale,"model_scale":model_scale,"row_y":[points[0].y,points[1].y,points[2].y]})
	print(JSON.stringify({"checks":checks,"rows":rows,"scope":"Parent direct fixed-layout coordinate check, no visual or performance claim"}))
	quit()
