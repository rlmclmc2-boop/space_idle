extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func capture(scene: Node, name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../" + name + ".png")

func configure(scene: Node, count: int) -> void:
	var g: BattleGame = scene.game
	g.start(1, false)
	g.group_index = g.db.levels[0].groups.size()-1
	g.spawn_group()
	var template: Dictionary = g.enemies[0].duplicate(true)
	g.enemies.clear()
	for i in range(count):
		var enemy := template.duplicate(true)
		enemy.uid = 9000 + i
		enemy.slot = i
		enemy.size = 1
		enemy.boss = false
		enemy.y = 198 + i * 44
		enemy.des = "抵抗物理与能量的超长飞船名称测试" if i == 0 else "护卫飞船"
		enemy.hp = 123450 * (i+1)
		enemy.max_hp = 1500000
		enemy.armourType = 1 + i % 2
		g.enemies.append(enemy)
	g.paused = false
	g.pending_unlocks.clear()
	scene.message_time = 0
	scene.shake = 0

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	for count in [1, 2, 5, 6, 10]:
		configure(scene, count)
		var cards: Array = scene.boss_health_cards()
		check(cards.size() == count, "%d ships have independent health cards" % count)
		var valid := true
		var battle_area: Rect2 = scene.battle_clip.get_global_rect().intersection(scene.get_viewport_rect())
		for i in range(cards.size()):
			var rect: Rect2 = cards[i].rect
			valid = valid and battle_area.encloses(rect)
			for j in range(i): valid = valid and not rect.intersects(cards[j].rect)
		check(valid, "%d cards fit battle area without overlap" % count)
		if count == 10: await capture(scene, "boss-health-ten")
	var initial: Array = scene.boss_health_cards()
	scene.game.enemies[0].size = 3
	scene.game.enemies[0].boss = true
	check(scene.boss_health_cards().size() == 10 and scene.boss_health_cards()[0].rect == initial[0].rect, "Size and legacy boss flag do not affect health card inclusion or layout")
	scene.game.enemies[0].hp = 12
	check(scene.boss_health_cards()[0].health.begins_with("12 /") and scene.boss_health_cards()[0].ratio < initial[0].ratio, "Each card tracks its own current health")
	scene.game.enemies[0].hp = 0
	var remaining: Array = scene.boss_health_cards()
	check(remaining.size() == 9 and remaining[0].enemy.uid == 9001 and remaining[0].rect == initial[1].rect, "Dead ship removed without shifting other cards")
	scene.game.group_index = 1
	check(scene.boss_health_cards().is_empty(), "Earlier wave does not show boss cards even with large hulls")
	scene.game.group_index = scene.game.db.levels[0].groups.size()
	scene.game.state = BattleGame.State.LEVEL_CLEAR
	check(scene.boss_health_cards().is_empty(), "Clear state hides old encounter cards")
	scene.game.profile.highestLevel = 2
	check(scene.game.start(2, false), "Next stage starts")
	check(scene.boss_health_cards().is_empty(), "Next stage does not retain previous health cards")
	configure(scene,2)
	for i in range(2):
		scene.game.enemies[i].size = 3
		scene.game.enemies[i].boss = true
		scene.game.enemies[i].y = 350 + i*110
	await capture(scene, "boss-health-two")
	scene.game.paused = true
	await capture(scene, "boss-health-paused")
	print("Boss health cards: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
