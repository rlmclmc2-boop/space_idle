extends SceneTree

var checks := 0
var failures := 0
var db: ShipDatabase
var game: BattleGame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func fresh() -> BattleGame:
	var result := BattleGame.new(db, false)
	result.profile.highestLevel = (int(db.unlock_row("feature","jewels").level)+1)
	return result

func add(id: String, level := 1) -> Dictionary:
	var gem := game.new_jewel(id, level)
	game.profile.jewels.append(gem)
	return gem

func equip_gem(id: String, category := "weapons", index := 0, level := 1) -> Dictionary:
	var gem := add(id,level)
	var entry := game.slot_entry(category,index)
	var socket: int = entry.get("sockets",[]).size()
	for i in entry.get("sockets",[]).size():
		if entry.sockets[i].is_empty():
			socket = i
			break
	check(game.socket_jewel(category,index,socket,int(gem.token)),"Socket fixture " + id)
	return gem

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	db = ShipDatabase.new()
	db.config.equipmentSocket="1|1,20|2,40|3"
	check(db.data.get("jewel",{}).size()==6,"Real jewel source projected")
	for id in db.data.jewel:
		check(not db.jewel_effect(str(id)).is_empty(),"Every authored func has an adapter: " + str(id))
	game = fresh()
	game.profile.highestLevel = (int(db.unlock_row("feature","jewels").level)+1)-1
	check(not game.jewels_unlocked(),"Locked below gate")
	game.profile.highestLevel += 1
	check(game.jewels_unlocked(),"Unlocked at configured gate")
	db.unlock_row("feature","jewels").level+=1
	check(not game.jewels_unlocked(),"Gate responds to config changes")
	db.unlock_row("feature","jewels").level-=1
	db.config.jewelCreat = 10
	game.profile.jewelFragments = 24.0
	check(game.pickup_jewel_fragment(),"Successful unified fragment pickup")
	check(game.profile.jewels.size()==2 and game.profile.jewelFragments==0,"Batch creates two level-one gems and drops sub-cost tail")
	game.profile.jewels.clear()
	for i in 199:add("1")
	game.profile.jewelFragments=24.0
	game.pickup_jewel_fragment()
	check(game.profile.jewels.size()==199 and game.profile.jewelFragments==25,"Batch waits until all planned gems fit")
	check(game.pickup_jewel_fragment() and game.profile.jewelFragments==26,"Pending batch still credits fragments")
	var tokens: Array=[]
	for i in 3:tokens.append(game.profile.jewels[i].token)
	var before := game.profile.duplicate(true)
	check(not game.combine_jewels([tokens[0],tokens[0],tokens[1]]) and game.profile==before,"Duplicate selection atomic failure")
	check(not game.combine_jewels([tokens[0],str(tokens[0]),tokens[1]]) and game.profile==before,"Mixed-type duplicate token cannot bypass atomic combine")
	check(not game.combine_jewels([tokens[0],tokens[1]]),"Insufficient combine")
	game.profile.jewels[1].id="2"
	check(not game.combine_jewels(tokens),"Combine refuses mixed IDs")
	game.profile.jewels[1].id="1"
	game.profile.jewels[1].level=2
	check(not game.combine_jewels(tokens),"Combine refuses mixed levels")
	game.profile.jewels[1].level=1
	check(game.combine_jewels(tokens) and game.profile.jewels.size()==199,"Combine frees space and settles held fragments")
	check(not game.combine_jewels(tokens),"Repeated stale combine cannot duplicate")
	check(game.profile.jewels.any(func(gem):return gem.level==2),"Combine result one level higher")
	check(game.profile.jewelFragments==0,"Held fragments settle once after enough slots open")
	game = fresh()
	var authored_max: int=db.data.jewel["1"].maxLevel
	db.data.jewel["1"].maxLevel=10
	var a := add("1",10)
	var b := add("1",10)
	var c := add("1",10)
	check(not game.combine_jewels([a.token,b.token,c.token]),"Max level cannot combine")
	check(game.profile.jewels.size()==3,"Max-level gems remain in inventory")
	db.data.jewel["1"].maxLevel=authored_max
	db.config.jewelCreat=1000
	game = fresh()
	add("3",2);add("1",3);add("2",3);add("1",1)
	game.sort_jewels(false)
	check(game.profile.jewels[0].id=="1" and game.profile.jewels[3].id=="3","ID sort")
	game.sort_jewels(true)
	check(game.profile.jewels[0].id=="1" and game.profile.jewels[1].id=="2" and game.profile.jewels[3].level==1,"Descending level and deterministic ID tie")
	game = fresh()
	var entry := game.slot_entry("weapons",0)
	check(game.equipment_socket_count(entry)==1,"Level 1 socket source")
	entry.level=20
	check(game.equipment_socket_count(entry)==2,"Level 20 socket source")
	entry.level=40
	check(game.equipment_socket_count(entry)==3,"Level 40 socket source")
	var installed := equip_gem("1")
	check(game.profile.jewels.is_empty(),"Socket transfers ownership")
	var duplicate := add("1",2)
	check(not game.socket_jewel("weapons",0,1,int(duplicate.token)),"Same ID across levels rejected in domain")
	var wrong := add("2")
	check(not game.socket_jewel("weapons",0,1,int(wrong.token)),"Equipment category restriction")
	entry.attacks=100
	check(game.jewel_equipment_stat(entry)==ceilf(game.equipment_stat("laser",40)*1.2),"Proficiency func uses weapon history")
	check(game.unsocket_jewel("weapons",0,0,int(installed.token)),"Unsocket returns bag")
	check(game.jewel_equipment_stat(entry)==game.equipment_stat("laser",40),"Removing modifier restores base")
	check(not game.unsocket_jewel("weapons",0,0,int(installed.token)),"Double unsocket rejected")
	check(game.socket_jewel("weapons",0,0,int(installed.token)),"Resocket")
	check(game.socket_jewel("weapons",0,0,int(duplicate.token)),"Replace same ID at a higher level")
	check(entry.sockets[0].token==duplicate.token and not game.jewel_inventory(int(installed.token)).is_empty() and game.jewel_inventory(int(duplicate.token)).is_empty(),"Replacement transfers both gems exactly once")
	check(not game.socket_jewel("weapons",0,0,int(duplicate.token)),"Repeated replacement with consumed token rejected")
	check(game.socket_jewel("weapons",0,0,int(installed.token)),"Restore replacement fixture")
	before=game.profile.duplicate(true)
	check(not game.socket_jewel("weapons",0,0,int(wrong.token)) and game.profile==before,"Incompatible replacement leaves both owners unchanged")
	while game.profile.jewels.size()<200:
		add("1")
	before=game.profile.duplicate(true)
	check(game.socket_jewel("weapons",0,0,int(duplicate.token)) and game.profile.jewels.size()==200 and entry.sockets[0].token==duplicate.token and not game.jewel_inventory(int(installed.token)).is_empty(),"Full bag exchanges both owners without increasing size")
	check(game.socket_jewel("weapons",0,0,int(installed.token)) and game.profile.jewels.size()==200 and entry.sockets[0].token==installed.token and not game.jewel_inventory(int(duplicate.token)).is_empty(),"Reverse exchange restores both owners with unchanged capacity")
	check(not game.unsocket_jewel("weapons",0,0,int(installed.token)) and entry.sockets[0].token==installed.token,"Full bag preserves socket ownership")
	check(game.unequip_slot("weapons",0) and game.module_entry("weapons",0).sockets[0].token==installed.token,"Full bag permits unloading while module retains gem")
	game.profile.jewels.clear()
	check(game.equip_slot("weapons",1,"cannon")==false,"Locked equipment fixture remains protected")
	game.profile.unlocked.append("cannon")
	check(game.equip_slot("weapons",1,"cannon"),"Second weapon installed")
	var second := add("1",2)
	check(game.socket_jewel("weapons",1,0,int(second.token)),"Same jewel ID allowed on another equipment")
	check(game.unequip_slot("weapons",1) and game.module_entry("weapons",1).sockets[0].token==second.token,"Equipment removal retains module gem")
	game.profile.cleared=range(1,51)
	var next_ship: String=db.ships.keys()[1]
	check(game.switch_ship(next_ship) and game.module_entry("weapons",0).sockets[0].token==installed.token,"Changing ship preserves installed module gems")
	check(game.stat("laser")==0,"Empty module gem stays inactive after hull change")
	game = fresh()
	entry=game.slot_entry("weapons",0)
	var crit_gem := equip_gem("5")
	var crit := game.jewel_critical(entry)
	check(is_equal_approx(crit.x,0.105) and crit.y==float(db.config.baseCriDmg),"Critical rate and configured base damage")
	db.data.jewel["5"].para_2=1.0
	game.start(1,false);game.spawn_group()
	var target: Dictionary=game.enemies[0]
	game.jewel_fire(0,target,db.equip("laser",1),Vector2.ZERO)
	check(game.projectiles.back().damage==game.jewel_equipment_stat(entry)*db.config.baseCriDmg,"Guaranteed crit scales exactly once")
	game.unsocket_jewel("weapons",0,0,int(crit_gem.token))
	check(game.jewel_critical(entry).x==0,"Unsocket clears crit")
	game = fresh()
	db.config.jewelDrop=1.0
	game.start(1,false);game.spawn_group()
	game.profile.highestLevel=(int(db.unlock_row("feature","jewels").level)+1)
	target=game.enemies[0]
	game.hit_enemy(target,float(target.hp)*100,0)
	var jewel_drops: Array=game.drops.filter(func(drop):return drop.has("jewel"))
	check(jewel_drops.size()==1,"Actual death emits one jewel drop")
	game.hit_enemy(target,100,0)
	check(game.drops.filter(func(drop):return drop.has("jewel")).size()==1,"Repeated dead-enemy event does not reroll")
	game.jewel_kill_drop(target)
	check(game.drops.filter(func(d):return d.has("jewel")).size()==1,"Drop entry itself rejects repeated death notifications")
	var drop: Dictionary=jewel_drops[0]
	game.collect_near(Vector2(drop.x,drop.y),false)
	check(game.drops.has(drop),"Fragments require click rather than hover")
	game.collect_near(Vector2(drop.x,drop.y),true)
	check(not game.drops.has(drop),"Manual click picks fragment")
	var count_before: float=game.profile.jewelFragments
	game.collect(drop,true)
	check(game.profile.jewelFragments==count_before,"Repeated pickup cannot duplicate fragments")
	game.jewel_kill_drop({"x":target.x,"y":target.y})
	drop=game.drops.filter(func(d):return d.has("jewel"))[0]
	game.state=BattleGame.State.MAIN_MENU
	game.tick(1.99)
	check(game.drops.has(drop),"No premature auto-pickup")
	game.tick(0.02)
	check(not game.drops.has(drop),"Auto pickup at 2 seconds")
	count_before=game.profile.jewelFragments
	game.collect(drop,true)
	check(game.profile.jewelFragments==count_before,"Auto then manual pickup at same boundary only rewards once")
	while game.profile.jewels.size()<200:
		add("1")
	game.jewel_kill_drop({"x":target.x,"y":target.y})
	drop=game.drops.filter(func(d):return d.has("jewel"))[0]
	count_before=game.profile.jewelFragments
	game.collect(drop,true);game.tick(2.1)
	check(not game.drops.has(drop) and game.profile.jewelFragments==count_before+1,"Full bag accepts manual pickup without losing fragments")
	check(game.profile.jewelFragments>=0,"Fragment balances remain nonnegative")
	# Save/load only inside run.py's copied project and redirected user directory.
	game = fresh()
	game.profile.cleared=range(1,(int(db.unlock_row("feature","jewels").level)+1))
	game.rebuild_unlocks()
	game.profile.jewelFragments=15.0
	add("3",2)
	equip_gem("5")
	game.slot_entry("weapons",0).attacks=123
	game.save_enabled=true;game.save_progress();game.save_enabled=false
	var restored:=BattleGame.new(db,false)
	restored.load_progress()
	check(restored.profile.jewels.size()==1 and restored.profile.jewels[0].id=="3" and restored.profile.jewels[0].level==2,"Bag save roundtrip")
	check(restored.profile.jewelFragments==15 and restored.slot_entry("weapons",0).sockets[0].id=="5","Fragments and sockets roundtrip")
	check(restored.slot_entry("weapons",0).attacks==123,"History persisted")
	check(restored.jewel_critical(restored.slot_entry("weapons",0))==game.jewel_critical(game.slot_entry("weapons",0)),"Load derives effects without duplication")
	var old_token: int=restored.profile.jewels[0].token
	restored.load_progress()
	check(restored.jewel_critical(restored.slot_entry("weapons",0))==game.jewel_critical(game.slot_entry("weapons",0)),"Repeated loading does not accumulate attributes")
	check(restored.jewel_inventory(old_token).is_empty(),"Reload invalidates old UI tokens")
	var legacy:=game.profile.duplicate(true)
	legacy.erase("jewels");legacy.erase("jewelFragments")
	for e in legacy.loadout.weapons:
		e.erase("sockets");e.erase("attacks")
	var file:=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	restored=BattleGame.new(db,false);restored.load_progress()
	check(restored.profile.jewels.is_empty() and restored.profile.jewelFragments==0 and restored.slot_entry("weapons",0).get("sockets",[]).is_empty(),"Old save initializes safely")
	await effect_tests()
	print("Jewel domain: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func effect_tests() -> void:
	db.config.equipmentSocket=10
	game=fresh()
	game.start(1,false);game.spawn_group()
	game.profile.highestLevel=(int(db.unlock_row("feature","jewels").level)+1)
	var entry:=game.slot_entry("weapons",0)
	equip_gem("4")
	db.data.jewel["4"].para_2=1.0
	game.queue_jewel_repeats(0,1.0)
	game.advance_jewel_repeats(0.49)
	check(game.projectiles.is_empty(),"Repeat waits 0.5 seconds")
	game.advance_jewel_repeats(0.02)
	check(game.projectiles.size()==1 and game.jewel_repeats.is_empty(),"Repeat emits once without recursion")
	check(game.projectiles[0].damage==game.jewel_equipment_stat(entry)*1.2,"Repeat damage modifier")
	game=fresh()
	equip_gem("2","defence")
	entry=game.slot_entry("defence",0)
	entry.hits=100
	check(game.stat("armour")==ceilf(game.equipment_stat("armour",1)*1.2),"Adaptation defence capacity")
	equip_gem("3","defence")
	game.player.armour=1
	game.jewel_defence_times[0]=4.0
	game.advance_jewel_repair(1)
	check(game.player.armour>1,"Auto repair after delay")
	game.jewel_defence_times[0]=0.0
	var health:=float(game.player.armour)
	game.advance_jewel_repair(1)
	check(game.player.armour==health,"Repair interrupted")
	equip_gem("6","defence")
	game.advance_jewel_repair(1)
	check(game.player.armour>health,"Tenacity preserves reduced repair")
	game=fresh()
	game.profile.loadout.defence=[{"key":"armour","level":1},{"key":"armour","level":1}]
	game.reset_player()
	equip_gem("3","defence",0)
	var capacity:=game.jewel_equipment_stat(game.slot_entry("defence",0))
	game.player.armour=capacity
	game.jewel_defence_damage={0:0.0,1:capacity}
	game.jewel_defence_times[0]=10.0
	game.advance_jewel_repair(1)
	check(game.player.armour==capacity,"Full repaired module cannot heal other damaged module")
