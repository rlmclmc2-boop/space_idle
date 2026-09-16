extends RefCounted
## Source-image coordinates; shared by rendering and combat muzzle placement.
const CANVAS := Vector2(1774, 887)
const CELL_PIXELS := 44.0
const SOCKETS := {
	"Frigate": [Vector2(991,335), Vector2(969,459), Vector2(990,581)],
	"Destroyer": [Vector2(721,261), Vector2(963,287), Vector2(721,595), Vector2(962,575)],
	"Cruiser": [Vector2(790,362), Vector2(1109,363), Vector2(750,524), Vector2(997,521), Vector2(1269,525)],
	"Battleship": [Vector2(795,382), Vector2(999,383), Vector2(1203,383), Vector2(795,641), Vector2(999,641), Vector2(1203,641)],
	"Heavy_Battleship": [Vector2(818,359), Vector2(1007,359), Vector2(1194,359), Vector2(1387,359), Vector2(818,580), Vector2(1007,580), Vector2(1194,580), Vector2(1387,580)]
}
const INNER_DIAMETER := {"Frigate":40.0, "Destroyer":55.0, "Cruiser":50.0, "Battleship":60.0, "Heavy_Battleship":55.0}
const MODULE_VISUAL_SCALE := 2.5

static func scale_for(ship: Dictionary) -> float:
	return float(ship.get("size", 1)) * CELL_PIXELS / CANVAS.y

static func enemy_scale_for(ship: Dictionary) -> float:
	# Every enemy occupies one formation slot; size is a visual tier only.
	return (48.0 + clampf(float(ship.get("size",1))-1.0,0.0,5.0)*16.0) / CANVAS.y

static func center(key: String, index: int) -> Vector2:
	return SOCKETS[key][index] - CANVAS / 2.0

static func module_width(key: String) -> float:
	return float(INNER_DIAMETER[key]) * 0.78 * MODULE_VISUAL_SCALE

static func muzzle(key: String, index: int) -> Vector2:
	return center(key, index) + Vector2(module_width(key) / 2.0, 0)
