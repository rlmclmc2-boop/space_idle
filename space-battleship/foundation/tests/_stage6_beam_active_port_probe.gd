extends SceneTree
const Session=preload("res://src/game_session.gd")
const Art=preload("res://scripts/approved_weapon_art.gd")
func _initialize()->void:
	var status=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:quit(1);return
	call_deferred("_run")
func _fixture(endless:bool,target_x:float=446.0)->Dictionary:
	var session=Session.new()
	var ready:Dictionary=session.initialize("res://generated/config.json",61)
	if ready.ok:ready=session.campaign_system.accept_reforge(session.campaign_system.save_state(),8)
	if not ready.ok:return ready
	session.equipment.refresh_availability(session.campaign_system.available,8,false)
	ready=session.equipment.equip_slot("weapon:0","longLaser",session.equipment_inputs(),session.publish_equipment_refit)
	if ready.ok and endless:
		var donor:Dictionary=session.equipment.drone_weapon_source("laser",0,0,session._research_factors,session._reactor_factors,session.battle.wave_inputs().motion)
		if not donor.ok:return donor
		donor.weapon.interval=1000000.0;donor.weapon.remaining=1000000.0
		ready=session.set_equipped_drone_contributions([{"id":"endless-port-probe","generation":1,"quality":"legendary","weapon":donor.weapon,"legendary_effect":"endless_beam","legendary_parameters":{"maximum_multiplier_bonus":1.0}}])
	if ready.ok:ready=session.start_campaign_sortie(1)
	if not ready.ok:return ready
	var value:Dictionary=session.battle._values.weapons["weapon:0"].duplicate()
	value.base="1e2"
	ready=session.battle._kernel.set_player_values({"weapon:0":value},{},"growth","")
	if not ready.ok:return ready
	var inputs:Dictionary=session.battle.wave_inputs()
	var setup:Dictionary=session.campaign_system.prepare_wave(session.equipment.enemy_override,inputs.geometry,inputs.motion)
	var first:Dictionary=setup.wave.enemies[0]
	first.hp="2e2";first.max_hp="2e2";first.shield="0";first.max_shield="0";first.armourType=0;first.slot=4
	var other:Dictionary=first.duplicate(true)
	other.uid=2;other.slot=8;other.x=target_x;other.hp="1e6";other.max_hp="1e6"
	setup.wave.enemies=[first,other];setup.wave.weapons=[]
	ready=session.battle.start_wave(setup)
	if not ready.ok:return ready
	return {"ok":true,"session":session}
func _run()->void:
	var checks:int=0
	var failures:int=0
	for endless in [false,true]:
		for mode in ["small","large","native_segments","review_case"]:
			var fixture:Dictionary=_fixture(endless,360.0 if mode=="review_case" else 446.0)
			if not fixture.ok:printerr("BEAM_PORT_FIXTURE_FAILED ",fixture);quit(1);return
			var session=fixture.session
			var step:float=0.01 if mode=="small" else 2.0 if mode=="large" else 0.37
			var steps:int=300 if mode=="small" else 2 if mode=="large" else 3 if mode=="review_case" else 9
			var case_before:int=failures
			var seen_second:bool=false
			var seen_same_serial:bool=false
			var targets:Dictionary={}
			for frame in steps:
				if mode=="review_case":step=1.11 if frame==0 else 0.37
				session.battle.begin_frame()
				var ok:bool=session.battle._kernel.advance(step) if mode=="native_segments" else bool(session.battle.advance(step).ok)
				if not ok:printerr("BEAM_PORT_ADVANCE_FAILED");quit(1);return
				var details:Dictionary=session.battle._kernel.geometry_details()
				for flight in details.flights:
					if not flight.beam or flight.source_id!="weapon:0":continue
					var target:Dictionary={}
					for actor in session.battle._kernel.enemy_views():
						if actor.uid==flight.target_uid and not actor.dead:target=actor;break
					if target.is_empty():continue # Awaiting an endless rebind; it is not rendered.
					var pose:Dictionary=session.battle._weapon_poses["weapon:0"]
					var reference:Dictionary=Art.player_pose("longLaser",session.battle._weapon_manifest.longLaser,session.battle._weapon_art.longLaser.get_size(),pose.pivot,(Vector2(target.x,target.y)-Vector2(pose.pivot)).angle(),session.battle._hull_bounds(session.battle._player_hull).size.y,session.battle._player_art)
					var expected:Vector2=reference.ports[int(flight.port_index)]
					var visible_mismatch:bool=mode!="native_segments" and pose.ports[int(flight.port_index)].distance_to(expected)>0.0001
					if flight.launch_point.distance_to(expected)>0.0001 or flight.launch_screen_point.distance_to(expected)>0.0001 or visible_mismatch:
						if failures<12:printerr("BEAM_ACTIVE_PORT_FAILED endless=",endless," mode=",mode," clock=",session.battle._kernel.presentation_clock()," target=",target.uid," serial=",flight.serial," numeric=",flight.launch_point," screen=",flight.launch_screen_point," expected=",expected)
						failures+=1
					checks+=1
					if target.uid==2:seen_second=true
					if targets.has(flight.serial) and targets[flight.serial]!=target.uid:seen_same_serial=true
					targets[flight.serial]=target.uid
				if mode=="native_segments":session.battle._kernel.take_results()
			if not seen_second or endless and mode!="large" and not seen_same_serial:
				printerr("BEAM_PORT_COVERAGE_FAILED endless=",endless," mode=",mode," second=",seen_second," same_serial=",seen_same_serial);quit(1);return
			print("BEAM_ACTIVE_PORT_CASE endless=",endless," mode=",mode," same_serial_retarget=",seen_same_serial," failures=",failures-case_before)
	print("STAGE6_BEAM_ACTIVE_PORTS_ACROSS_DEATH_REBIND_AND_LARGE_DT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
