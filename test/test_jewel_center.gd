extends SceneTree

var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func _initialize() -> void:
	var db:=ShipDatabase.new()
	var game:=BattleGame.new(db,false)
	game.save_enabled=false
	game.profile.highestLevel=50
	game.profile.jewelFragments=0.0
	game.profile.jewels.clear()
	var entry:=game.module_entry("weapons",0)
	entry.level=40
	entry.sockets=[game.new_jewel("7"),{},{}]
	var original: int=entry.sockets[0].token
	game.profile.jewels=[game.new_jewel("7"),game.new_jewel("7"),game.new_jewel("7",2),game.new_jewel("2")]
	var notices: Array=[]
	game.event.connect(func(kind,info):
		if kind=="jewels_changed":notices.append(info))
	var old: Dictionary=game.profile.duplicate(true)
	var old_critical:=game.jewel_critical(entry).x
	check(not game.upgrade_socket_jewel("weapons",0,0,original+999) and game.profile==old,"Stale installed token cannot consume materials")
	check(game.can_upgrade_socket_jewel("weapons",0,0),"Installed gem has enough same-level materials")
	check(game.upgrade_socket_jewel("weapons",0,0,original),"Installed upgrade succeeds")
	check(entry.sockets[0].level==2 and entry.sockets[0].token!=original and game.profile.jewels.size()==2,"Upgrade consumes two bag gems and replaces installed identity once")
	check(notices.size()==1 and notices[0].slot=="weapons_0","Installed upgrade emits one targeted notification")
	check(game.jewel_critical(entry).x>old_critical,"Upgraded gem uses existing critical effect")
	old=game.profile.duplicate(true)
	check(not game.upgrade_socket_jewel("weapons",0,0,original) and game.profile==old,"Repeated old request cannot upgrade twice")
	var protected:=game.new_jewel("7",2)
	protected.locked=true
	game.profile.jewels.append(protected)
	check(not game.can_upgrade_socket_jewel("weapons",0,0),"Protected bag materials excluded")
	protected.erase("locked")
	check(game.can_upgrade_socket_jewel("weapons",0,0),"Unprotected material becomes available")
	db.config.jewelCombine=0
	old=game.profile.duplicate(true)
	check(not game.upgrade_socket_jewel("weapons",0,0,int(entry.sockets[0].token)) and game.profile==old,"Invalid recipe never consumes installed gem")
	db.config.jewelCombine=3
	entry.sockets[0].locked=true
	check(not game.can_upgrade_socket_jewel("weapons",0,0),"Protected installed gem cannot upgrade")
	entry.sockets[0].erase("locked")
	entry.sockets[0].level=db.jewel_max_level("7")
	check(not game.can_upgrade_socket_jewel("weapons",0,0),"Max-level installed gem cannot upgrade")
	entry.sockets[0].level=2
	game.profile.highestLevel=1
	check(not game.can_upgrade_socket_jewel("weapons",0,0),"Locked feature cannot upgrade installed gems")
	game.profile.highestLevel=50
	var dormant: Dictionary={"key":"laser","level":40,"sockets":[game.new_jewel("7"),{},{}],"attacks":0,"hits":0}
	while game.module_entries("weapons").size()<=game.active_slot_count("weapons"):
		game.profile.loadout.weapons.append(dormant.duplicate(true))
	var dormant_index:=game.module_entries("weapons").size()-1
	var dormant_entry:=game.module_entry("weapons",dormant_index)
	var new_gem:=game.new_jewel("7",2)
	game.profile.jewels.append(new_gem)
	var damage:=game.stat("laser")
	check(game.socket_jewel("weapons",dormant_index,0,int(new_gem.token)),"Dormant module supports replacement")
	check(game.stat("laser")==damage,"Dormant modification does not affect active battle stats")
	dormant_entry.key=""
	check(game.unsocket_jewel("weapons",dormant_index,0,int(new_gem.token)),"Empty dormant module exposes and returns retained gems")
	old=game.profile.duplicate(true)
	check(not game.socket_jewel("weapons",dormant_index,0,int(new_gem.token)) and game.profile==old,"Empty module still cannot accept new gems")
	game.profile.jewels.clear()
	entry.sockets=[game.new_jewel("7"),{},{}]
	for i in 200:game.profile.jewels.append(game.new_jewel("7"))
	game.profile.jewelFragments=1000
	var replace_token: int=game.profile.jewels[0].token
	var old_token: int=entry.sockets[0].token
	check(game.socket_jewel("weapons",0,0,replace_token) and game.profile.jewels.size()==200 and game.profile.jewelFragments==1000,"Full bag replacement does not trigger a false free-slot refill")
	check(not game.unsocket_jewel("weapons",0,0,replace_token) and not game.jewel_inventory(old_token).is_empty(),"Full bag unsocket remains blocked; old gem is retained")
	notices.clear()
	check(game.upgrade_socket_jewel("weapons",0,0,replace_token),"Full bag can upgrade installed gem")
	check(game.profile.jewels.size()==200 and game.profile.jewelFragments==800 and notices.size()==1,"Upgrade settles only the two freed spaces once")
	var owners: Dictionary={}
	for gem in game.profile.jewels:owners[int(gem.token)]=true
	check(not owners.has(int(entry.sockets[0].token)) and owners.size()==200,"Unique ownership remains after replacement upgrade and refill")
	game.profile.jewelFragments=0
	game.profile.jewels.clear()
	game.save_enabled=true
	game.save_progress()
	var loaded:=BattleGame.new(db)
	loaded.save_enabled=false
	check(loaded.module_entry("weapons",0).sockets[0].level==2,"Installed upgrade round trips through isolated save")
	print("Jewel center domain: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
