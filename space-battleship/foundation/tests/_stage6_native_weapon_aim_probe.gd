extends SceneTree
const Session = preload("res://src/game_session.gd")
const Art = preload("res://scripts/approved_weapon_art.gd")
func _initialize() -> void:
	var status=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:quit(1);return
	call_deferred("_run")
func _check(ok:bool,message:String)->bool:
	if ok:return true
	printerr("NATIVE_WEAPON_AIM_FAILED ",message);quit(1);return false
func _run()->void:
	var births:int=0
	for key in ["laser","cannon","missile","longLaser"]:
		var session=Session.new()
		if not _check(session.initialize("res://generated/config.json",818).ok,"initialize"):return
		if not _check(session.campaign_system.accept_reforge(session.campaign_system.save_state(),8).ok,"availability"):return
		session.equipment.refresh_availability(session.campaign_system.available,8,false)
		if key!="laser" and not _check(session.equipment.equip_slot("weapon:0",key,session.equipment_inputs(),session.publish_equipment_refit).ok,"equip "+key):return
		if not _check(session.start_campaign_sortie(2).ok,"sortie"):return
		session.campaign_system._state.points=[{"id":33008,"position":0.14}]
		session.campaign_system._state.point=0
		var inputs:Dictionary=session.battle.wave_inputs()
		var setup:Dictionary=session.campaign_system.prepare_wave(session.equipment.enemy_override,inputs.geometry,inputs.motion)
		setup.wave.weapons=[]
		for actor in setup.wave.enemies:
			actor.hp="1e6";actor.max_hp="1e6";actor.shield="0";actor.max_shield="0"
			if int(actor.slot)==4:actor.hp="1"
		if not _check(session.battle.start_wave(setup).ok,"production group 33008"):return
		var first_uid:int=int(session.battle._kernel.enemy_views()[0].uid)
		var initial:Dictionary=session.battle._kernel.weapon_aims()["weapon:0"]
		if key=="laser" and not _check(initial.uid!=first_uid and initial.point==Vector2(446,350),"reported slot2/slot4 split"):return
		var native_before:Dictionary=session.battle.persistent_state().duplicate(true)
		for read in 20:session.battle._kernel.weapon_aims()
		if not _check(session.battle.persistent_state()==native_before,"aim query changed simulation"):return
		var seen:Dictionary={}
		var changed:bool=false
		for step in 1600:
			session.battle.begin_frame()
			if not _check(session.battle.advance(0.01).ok,"advance"):return
			var aims:Dictionary=session.battle._kernel.weapon_aims()
			var pose:Dictionary=session.battle._weapon_poses["weapon:0"]
			if aims.has("weapon:0"):
				var expected:float=(Vector2(aims["weapon:0"].point)-Vector2(pose.pivot)).angle()+PI*0.5
				if not _check(absf(angle_difference(expected,float(pose.angle)))<0.0001,"visible pose differs from native "+key):return
				if aims["weapon:0"].uid!=initial.uid and not session.battle._kernel.enemy_views()[0].dead:changed=true
			var details:Dictionary=session.battle._kernel.geometry_details()
			for flight in details.flights:
				if flight.hostile or flight.source_id!="weapon:0" or seen.has(flight.serial):continue
				seen[flight.serial]=true
				var target:Dictionary={}
				for actor in session.battle._kernel.enemy_views():
					if actor.uid==flight.target_uid:target=actor;break
				if not _check(not target.is_empty(),"birth target uid"):return
				var reference:Dictionary=Art.player_pose(key,session.battle._weapon_manifest[key],session.battle._weapon_art[key].get_size(),pose.pivot,(Vector2(target.x,target.y)-Vector2(pose.pivot)).angle(),session.battle._hull_bounds(session.battle._player_hull).size.y,session.battle._player_art)
				if not _check(flight.launch_point.distance_to(reference.ports[int(flight.port_index)])<0.0001 and flight.launch_screen_point.distance_to(reference.ports[int(flight.port_index)])<0.0001,"actual selected target muzzle "+key):return
			if changed and seen.size()>0:break
		if not _check(changed,"no retarget while first row stayed alive "+key):return
		if key!="cannon" and not _check(not seen.is_empty(),"no observed birth "+key):return
		births+=seen.size()
		print("NATIVE_WEAPON_AIM_GROUP33008_OK weapon=",key," first_uid=",first_uid," initial=",initial," observed_births=",seen.size())
	print("STAGE6_NATIVE_WEAPON_AIM_AND_REAL_BIRTH_PORTS_OK births=",births)
	quit(0)
