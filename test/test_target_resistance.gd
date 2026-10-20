extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	for key in ["laser", "cannon", "missile"]:
		var g := BattleGame.new(db,false)
		g.start(1,false)
		g.spawn_group()
		g.profile.unlocked = [key,"armour"]
		g.profile.loadout = g.empty_loadout(g.profile.selectedShip)
		g.profile.loadout.defence[0].key = "armour"
		g.reset_player()
		g.equip_slot("weapons",0,key)
		var weapon := db.equip(key,1)
		var damage_type := int(weapon.dmgtype)
		var base := g.enemies[0].duplicate(true)
		g.enemies.clear()
		for i in range(4):
			var enemy := base.duplicate(true)
			enemy.uid = i + 100
			enemy.x = 100.0 + i * 75
			enemy.y = 220.0
			enemy.hp = 1000000.0
			enemy.equipment = []
			enemy.armourType = damage_type if i < 2 else 3 - damage_type
			g.enemies.append(enemy)
		check(g.targets()[0].uid == 100,key+" default ordering unchanged")
		var ordered := g.targets(damage_type)
		check(ordered[0].uid == 102 and ordered[1].uid == 103 and ordered[2].uid == 100,key+" non-resistant first, positional ties retained")
		var fired: Array=[]
		g.event.connect(func(kind:String,info:Dictionary):
			if kind=="fire" and not info.shot.get("hostile",false):fired.append(int(info.shot.target.get("uid",-1))))
		var count := int(weapon.para1) if key=="missile" else 1
		g.cooldowns.weapons_0 = 0
		g.tick(0.001)
		check(not fired.is_empty() and fired[0] == 102,key+" actual firing prefers non-resistant")
		if key == "missile":
			check(fired.size()==count and fired.slice(0,mini(4,count))==[102,103,100,101].slice(0,mini(4,count)),"Missile distinct targets follow resistance ordering")
		for enemy in g.enemies:
			enemy.armourType = damage_type
		check(g.targets(damage_type)[0].uid == 100,key+" all resistant falls back to position")
		fired.clear()
		g.projectiles.clear()
		g.cooldowns.weapons_0 = 0
		g.tick(0.001)
		check(not fired.is_empty() and fired[0] == 100,key+" all resistant still fires")
		if key == "missile":
			fired.clear()
			g.projectiles.clear()
			g.enemies.resize(1)
			g.cooldowns.weapons_0 = 0
			g.tick(0.001)
			check(fired.size()==count and fired.all(func(uid):return uid==100) and g.missile_visual_spread(0,3)<g.missile_visual_spread(1,3) and g.missile_visual_spread(1,3)<g.missile_visual_spread(2,3),"Missile salvo retains distinct visual lanes with one target")
		for enemy in g.enemies:
			enemy.hp = 0
		check(g.targets(damage_type).is_empty(),key+" dead enemies excluded")
	print("Target resistance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
