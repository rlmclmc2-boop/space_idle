extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)

func fresh() -> BattleGame:
	var game := BattleGame.new(ShipDatabase.new(),false)
	game.profile.unlocked=["laser","armour","shield"]
	game.start(1,false)
	game.spawn_group()
	return game

func _initialize() -> void:
	var db := ShipDatabase.new()
	var keys := ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
	var weapons := [1,2,3,4,5]
	var defence := [1,1,2,2,3]
	for index in keys.size():
		check(int(db.ship(keys[index]).weaponSlots)==weapons[index] and int(db.ship(keys[index]).defenseSlots)==defence[index],"Excel ship capacity "+keys[index])
	var game := fresh()
	check(game.weapon_entries().size()==1 and game.defense_entries().size()==1,"opening hull has one of each slot")
	check(not game.ship_unlocked("Destroyer"),"later hull locked during first three stages")
	check(game.equip_slot("defence",0,"shield"),"first defence slot accepts shield")
	check(game.player.armour==0 and game.player.shield>0 and game.player_alive(),"pure shield is alive")
	game.hit_player(1,1)
	check(game.player_alive() and game.state!=BattleGame.State.RETREAT,"shield damage does not kill pure shield")
	game.hit_player(1.0e9,1)
	check(not game.player_alive() and game.state==BattleGame.State.RETREAT,"both depleted triggers retreat")
	game=fresh()
	game.equip_slot("defence",0,"shield")
	var before:float=float(game.player.shield)
	game.apply_enhancement_deferred("armour",5.0)
	check(game.player_alive() and game.player.armour==0 and float(game.player.shield)<before,"old armour debt pays current shield")
	game.hit_player(10,1)
	before=float(game.player.shield)
	var delay:float=float(game.db.equip("shield",1).para3)
	check(game.advance_jewel_repair(delay+1.0),"pure shield recovery advances")
	check(float(game.player.shield)>before and game.player_alive(),"pure shield recovers while alive")
	check(game.equip_slot("defence",0,"armour") and game.player_alive() and game.player.shield==0,"shield to armour swap remains alive")
	game=fresh()
	check(game.player.armour>0 and game.player.shield==0 and game.player_alive(),"pure armour is alive")
	game.hit_player(1,2)
	check(game.player_alive() and game.state!=BattleGame.State.RETREAT,"armour damage does not kill pure armour")
	check(game.unequip_slot("defence",0) and game.state==BattleGame.State.RETREAT,"empty final defence slot causes retreat")
	game=fresh()
	game.profile.cleared=range(1,21)
	check(game.switch_ship("Cruiser"),"mixed hull unlock and switch")
	check(game.equip_slot("defence",1,"shield"),"mixed defence accepts shield")
	check(game.player.armour>0 and game.player.shield>0,"mixed pools coexist")
	check(game.valid_loadout("Cruiser",game.profile.loadout),"mixed refit remains valid")
	game.db.config.dmgReduce=0.0
	game.hit_player(float(game.player.shield)+1.0,1)
	check(game.player.shield==0 and game.player.armour>0 and game.player_alive(),"mixed overflow uses armour and remains alive")
	print("Single slot survival: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
