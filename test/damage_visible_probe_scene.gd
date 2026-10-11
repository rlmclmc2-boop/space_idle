extends "res://scripts/battlefield.gd"
var visual_queries=0
func damage_layout_metrics(value:String,size_value:int,context:Dictionary)->Dictionary:
 visual_queries+=1
 return super.damage_layout_metrics(value,size_value,context)
func damage_text_position(origin:Vector2,value:String,size_value:int=19,excluded_entry:Dictionary={},layout_context:Dictionary={})->Vector2:
 visual_queries+=1
 return super.damage_text_position(origin,value,size_value,excluded_entry,layout_context)
func resolve_damage_origin(entry:Dictionary,context:Dictionary)->void:
 visual_queries+=1;super.resolve_damage_origin(entry,context)
func incoming_damage_origin(damage_type:int)->Vector2:
 visual_queries+=1
 return super.incoming_damage_origin(damage_type)
func incoming_damage_display_text(amount,absorbed,damage_type:int,size_value:int,maximum_width:float=556.0)->String:
 visual_queries+=1
 return super.incoming_damage_display_text(amount,absorbed,damage_type,size_value,maximum_width)
