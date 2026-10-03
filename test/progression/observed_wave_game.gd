extends "res://qa/presented_balance_game.gd"
## Read-only incoming-hit observer; production mitigation remains in super.
var incoming_by_type:Dictionary={}
var incoming_sample:Array=[]
func hit_player(raw,type:int,context:Dictionary={}) -> void:
	var armour_before:float=maxf(0,float(player.armour))
	var shield_before:float=maxf(0,float(player.shield))
	super.hit_player(raw,type,context)
	var lost_armour:float=maxf(0,armour_before-maxf(0,float(player.armour)))
	var lost_shield:float=maxf(0,shield_before-maxf(0,float(player.shield)))
	var key:=str(type)
	if not incoming_by_type.has(key):incoming_by_type[key]={"hits":0,"raw_requested":0.0,"armour_lost_clamped":0.0,"shield_lost_clamped":0.0}
	var totals:Dictionary=incoming_by_type[key]
	totals.hits+=1;totals.raw_requested+=float(raw)
	totals.armour_lost_clamped+=lost_armour;totals.shield_lost_clamped+=lost_shield
	if incoming_sample.size()<50:incoming_sample.append({"at":simulated_time,"type":type,"source_uid":context.get("source_uid",0),"raw_requested":float(raw),"armour_before":armour_before,"shield_before":shield_before,"armour_lost_clamped":lost_armour,"shield_lost_clamped":lost_shield})
