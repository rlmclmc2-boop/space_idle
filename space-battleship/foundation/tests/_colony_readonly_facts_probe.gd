extends SceneTree
const Crew = preload("res://src/systems/crew.gd")
const Planet = preload("res://src/systems/planet.gd")
const Galaxy = preload("res://src/systems/galaxy.gd")
const RunState = preload("res://src/systems/run_state.gd")
class MeteredAPI extends RefCounted:
	var native
	var calls: int = 0
	var powers: int = 0
	func apply(operation: String, operands: Array) -> Dictionary:
		calls += 1
		if operation == "pow": powers += 1
		return native.apply(operation, operands)
var api = MeteredAPI.new()
var failures: Array = []
var notices := {"crew":0, "planet":0, "galaxy":0}
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func amount(text: String) -> Dictionary:
	return api.apply("from_decimal", [text]).value
func equivalent(text: String, expected: String) -> bool:
	return api.apply("compare", [amount(text), amount(expected)]).scalar == 0
func by_id(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if row.id == id: return row
	return {}
func _initialize() -> void:
	var status = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		printerr("ExtensionRequired:", status)
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	api.native = ClassDB.instantiate("FoundationAmount")
	var config = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPACE_IDLE_GALAXY_PROBE_CONFIG")))
	var state = RunState.new()
	var crew = Crew.new(config.crew.crew, config.crew_config.crew_config, config.crew_assignment.crew_assignment, api, state)
	crew.refresh_availability(func(kind, id): return kind == "crew" and id == "navigator", false)
	crew.members_changed.connect(func(_ids): notices.crew += 1)
	var members: Array = crew.member_facts()
	check(members.size() == 1 and members[0].id == "navigator" and members[0].level == 0, "crew identity/order")
	check(not members[0].experience_enabled and members[0].experience_required == null and members[0].experience_fraction == null, "crew feature hidden")
	var locked: Array = crew.member_facts(["missing", "engineer"])
	check(locked.size() == 1 and locked[0].size() == 4 and locked[0].reason == "CrewLocked", "crew unknown/locked")
	crew.refresh_availability(func(_kind, _id): return true, false)
	var award: Dictionary = crew.award_exploration("navigator", false, amount("250"))
	var member: Dictionary = crew.member_facts(["navigator"])[0]
	check(award.ok and member.level == 2 and equivalent(member.experience,"30") and equivalent(member.experience_required,"144"), "crew remainder/single-level cost")
	check(absf(member.experience_fraction - 30.0/144.0) < 1e-12, "crew fraction")
	var calls: int = api.calls
	crew.member_facts(["navigator"])
	check(api.calls == calls, "crew unchanged cache")
	crew.award_exploration("navigator",false,amount("1"))
	var powers: int = api.powers
	member = crew.member_facts(["navigator"])[0]
	check(api.powers == powers and equivalent(member.experience,"31"), "crew changed experience reuses level requirement")
	member.level = 999
	check(crew.member_facts(["navigator"])[0].level == 2, "crew detached rows")
	var people_before: Dictionary = crew.step_assignments()
	check(crew.assign("navigator", "planet_explore", "1", "1", func(_kind,_target): return {"ok":true,"capacity":1}).ok, "crew explorer assign")
	var people: Dictionary = crew.step_assignments()
	check(people_before.explorers.is_empty() and people.explorers["1"] == ["navigator"], "current-frame personnel fresh")
	var planet = Planet.new(config.planet.planet, config.planet_build.planet_build, config.planet_buff.planet_buff, api, state)
	planet.refresh_availability(func(_kind,_id): return true, false)
	planet.status_changed.connect(func(_ids): notices.planet += 1)
	check(planet.facility_facts("01", {}, {}).is_empty(), "planet canonical identity")
	var planets: Dictionary = planet.save_state()
	var p: Dictionary = planets.planets["1"]
	p.exploration = 100
	p.running = true
	p.duration = 10.0
	p.elapsed = 9.0
	p.buildings.station = {"state":"built", "work":1}
	p.buildings.refinery = {"state":"built", "work":5}
	p.buildings.workshop = {"state":"ready", "work":10}
	p.buildings.shipyard = {"state":"building", "work":7}
	check(planet.restore_state(planets).ok, "planet fixture restore")
	var before: Dictionary = planet.save_state()
	var rows: Array = planet.facility_facts("1", people.explorers, people.builders)
	check(rows.size() == 4 and by_id(rows,"shipyard").required_work == 180 and by_id(rows,"shipyard").work == 7, "facility applicable work counts")
	check(by_id(rows,"shipyard").pause_reason == "MissingBuilders" and by_id(rows,"workshop").claim_allowed and by_id(rows,"workshop").source_factor == null, "facility pause/claim/current-source")
	check(by_id(rows,"station").source_factor == null and not planet.visual_snapshot("1").has("automatic"), "automatic stays explicit gap")
	check(planet.contributions().ok, "planet original contributions")
	var ratio: Dictionary = api.apply("to_ratio", [amount(by_id(rows,"refinery").source_factor), amount("1.27456062731926")])
	check(absf(float(ratio.scalar)-1.0) < 1e-12, "facility original source factor")
	calls = api.calls
	planet.facility_facts("1", people.explorers, people.builders)
	check(api.calls == calls, "facility static factor cache")
	check(crew.assign("engineer", "planet_build", "1:shipyard", "1", planet.assignment_capacity).ok, "builder assign")
	people = crew.step_assignments()
	check(by_id(planet.facility_facts("1", people.explorers, people.builders),"shipyard").pause_reason.is_empty(), "facility current personnel replaces old view")
	check(by_id(planet.facility_facts("1", {}, people.builders),"shipyard").pause_reason == "NoExplorer", "zero extra crew does not replace explorer")
	rows[0].state = "invented"
	check(planet.facility_facts("1",people.explorers,people.builders)[0].state != "invented" and planet.save_state() == before, "facility detached pure reads")
	check(planet.set_automatic("1",true).ok and notices.planet == 1, "automatic-only invalidation")
	planet.set_automatic("1",true)
	check(notices.planet == 1, "automatic no-op no invalidation")
	var progress: Dictionary = planet.advance(people.explorers,people.builders,1.0,func(): return {"enabled":false})
	check(progress.ok and by_id(planet.facility_facts("1",people.explorers,people.builders),"shipyard").work == 8, "facility completion cache invalidation")
	var accepted: Dictionary = planet.claim_build("1","workshop",func(_factors):
		var notice: Dictionary = planet.accept_prepared_claim()
		planet.publish_claim(notice)
		return {"ok":true})
	check(accepted.ok and by_id(planet.facility_facts("1",people.explorers,people.builders),"workshop").source_factor != null, "facility accepted claim invalidation")
	planets = planet.save_state()
	planets.planets["1"].buildings.refinery = {"state":"building","work":2}
	planets.planets["1"].running = false
	planets.planets["1"].duration = 0.0
	planets.planets["1"].elapsed = 0.0
	check(planet.restore_state(planets).ok and by_id(planet.facility_facts("1",{},{}),"refinery").pause_reason == "ExplorationNotRunning", "facility restore cache/first pause priority")
	planets.planets["1"].running = true
	planets.planets["1"].duration = 10.0
	check(planet.restore_state(planets).ok and by_id(planet.facility_facts("1",{},{}),"refinery").pause_reason == "NoExplorer", "zero-extra facility still needs explorer")
	check(by_id(planet.facility_facts("1",people.explorers,{}),"refinery").pause_reason.is_empty(), "zero-extra facility no builder required")
	var galaxy = Galaxy.new(config.galaxy.galaxy, config.galaxy_build.galaxy_build, config.galaxy_config.galaxy_config, api, state)
	check(galaxy.node_facts("galaxy_1","0",{}).is_empty(), "unavailable region hidden")
	galaxy.refresh_availability(func(_kind,_id): return true, {60:true}, false)
	galaxy.status_changed.connect(func(_ids): notices.galaxy += 1)
	var galaxies: Dictionary = galaxy.save_state()
	var region: Dictionary = galaxies.regions.galaxy_1
	var last_work: float = region.nodes["29"].explore_remaining
	region.nodes["0"].state = "active"
	region.nodes["0"].explored = true
	region.nodes["0"].explore_remaining = 0.0
	region.nodes["0"].building = "colony_ring"
	region.nodes["0"].level = 1
	region.active_count = 1
	region.total_levels = 1
	region.explored_count = 1
	region.nodes["1"].state = "exploring"
	region.nodes["1"].building = "heavy_element_refinery"
	region.nodes["1"].explore_remaining = 500.0
	region.active_node = "1"
	check(galaxy.restore_state(galaxies).ok, "galaxy fixture restore")
	var no_ledger: Dictionary = galaxy.node_facts("galaxy_1","0",{})
	check(galaxy._factors.is_empty() and no_ledger.contribution == null, "node query never repairs business ledger")
	check(galaxy.contributions().ok, "galaxy restored business ledger")
	var hidden: Dictionary = galaxy.node_facts("galaxy_1","1",{})
	check(hidden.building_id.is_empty() and hidden.name.is_empty() and hidden.effect_id.is_empty() and hidden.contribution == null and hidden.target_level == null, "node hidden drawn type")
	check(hidden.explore_required == 1000.0 and hidden.explore_remaining == 500.0 and hidden.progress_fraction == 0.5 and hidden.progress_block_reason == "NoGalaxyCrew", "exploration work units")
	check(galaxy.node_facts("missing","1",{}).is_empty() and galaxy.node_facts("galaxy_1","30",{}).is_empty(), "node region/key identity")
	check(galaxy.node_facts("galaxy_1","2",{}).reachable and not galaxy.node_facts("galaxy_1","4",{}).reachable, "original reachable shallow frontier")
	check(galaxy.node_facts("galaxy_1","29",{}).explore_required == last_work, "last-node original quota cached")
	var node: Dictionary = galaxy.node_facts("galaxy_1","0",{})
	check(node.effect_id == "crew_exp" and equivalent(node.contribution,"0.1") and node.progress_fraction == null, "node source increment not factor")
	calls = api.calls
	galaxy.node_facts("galaxy_1","0",{"galaxy_1":1})
	check(api.calls == calls, "node source text reuse")
	var saved: Dictionary = galaxy.save_state()
	galaxy.node_facts("galaxy_1","1",{"galaxy_1":1})
	check(galaxy.save_state() == saved and notices.galaxy == 0, "node query no business mutation or signal")
	region.nodes["1"].state = "constructing"
	region.nodes["1"].explored = true
	region.nodes["1"].explore_remaining = 0.0
	region.nodes["1"].construction_remaining = 15.0
	region.explored_count = 2
	check(galaxy.restore_state(galaxies).ok and galaxy.contributions().ok, "constructing fixture")
	node = galaxy.node_facts("galaxy_1","1",{"galaxy_1":1})
	check(node.construction_required == 30.0 and node.progress_fraction == 0.5 and node.target_level == 1 and equivalent(node.contribution,"0"), "construction seconds/zero current source")
	galaxies = Galaxy._initial(galaxy._definitions)
	region = galaxies.regions.galaxy_1
	region.phase = "developing"
	region.nodes["0"].state = "active"
	region.nodes["0"].building = "colony_ring"
	region.nodes["0"].explored = true
	region.nodes["0"].explore_remaining = 0.0
	region.nodes["0"].level = 1
	region.nodes["0"].upgrade_remaining = 180.0
	region.upgrades = ["0"]
	region.active_count = 1
	region.explored_count = 1
	region.total_levels = 1
	check(galaxy.restore_state(galaxies).ok and galaxy.contributions().ok, "upgrade fixture")
	node = galaxy.node_facts("galaxy_1","0",{})
	check(node.state == "active" and node.upgrading and node.target_level == 2 and node.upgrade_required == 360.0 and node.progress_fraction == 0.5 and equivalent(node.contribution,"0.1"), "upgrade work/old-level source")
	var advanced: Dictionary = galaxy.advance({"galaxy_1":1},1.0)
	check(advanced.ok and advanced.displayed == ["galaxy_1"], "mid-upgrade invalidation")
	check(galaxy.node_facts("galaxy_1","0",{"galaxy_1":1}).upgrade_remaining == 178.5, "upgrade shared power units")
	check(crew.assign("navigator","","","1",func(_kind,_target): return {"ok":true,"capacity":1}).ok, "release ordinary assignment")
	var notice_count: int = notices.crew
	check(crew.reserve_hyperspace("navigator","route").ok and crew.member_facts(["navigator"])[0].reservation_reason == "HyperspaceCrewReserved", "online reservation current state")
	check(crew.release_hyperspace("route") == ["navigator"] and crew.member_facts(["navigator"])[0].kind.is_empty() and notices.crew == notice_count + 2, "online reserve/release invalidations")
	var crew_save: Dictionary = crew.save_state()
	crew_save.members.navigator.level = 9223372036854775807
	check(crew.restore_state(crew_save).ok and crew.member_facts(["navigator"])[0].experience_required == null, "crew int64 terminal no new cap")
	check(state.is_running(), "queries do not stop RunState")
	if failures.is_empty(): print("PASS: crew identity/experience/reservation, fresh personnel, facility state/work/source, node hiding/work/source, detached pure reads, caches, automatic and mid-upgrade notifications")
	else: printerr("FAIL: ",failures)
	quit(0 if failures.is_empty() else 1)
