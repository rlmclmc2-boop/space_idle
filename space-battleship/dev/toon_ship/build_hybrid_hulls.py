"""Build the five compact presentation hulls and a one-weapon drone carrier.

Rebuild with Blender:
  blender --background --factory-startup --python-exit-code 1 \
    --python dev/toon_ship/build_hybrid_hulls.py

Plain Python --describe validates the authored layout without starting Blender.
The four existing weapon files are read-only inputs. No gameplay data is emitted.
Coordinates in SPECS are Godot coordinates: +Y up, -Z forward, meters.
"""

from __future__ import annotations

import itertools
import json
import math
import sys
from pathlib import Path


OUT = Path(__file__).resolve().parent
HULL_OUT = OUT / "hulls"
MANIFEST = OUT / "hybrid_manifest.json"
WEAPON_RADIUS = 1.24  # Conservative XZ AABB corner, largest existing weapon.
MIN_MOUNT_DISTANCE = 2.60
PALETTE = {
    "ProtoIvory": ((0.78, 0.77, 0.72), 0.0),
    "ProtoNavy": ((0.025, 0.055, 0.085), 0.0),
    # Dark torso separates ivory armor and weapons at the smallest ship size.
    "ProtoHullBlue": ((0.095, 0.19, 0.27), 0.0),
    "ProtoGraphite": ((0.11, 0.16, 0.20), 0.0),
    "ProtoCyan": ((0.025, 0.42, 0.57), 0.3),
    "ProtoEngine": ((0.025, 0.42, 0.57), 1.4),
}


def pentagon_mounts(radius=2.29, height=0.61):
    # Bow, port cheek, starboard cheek, port stern, starboard stern.
    return [
        [round(radius * math.sin(math.radians(angle)), 6), height,
         round(-radius * math.cos(math.radians(angle)), 6)]
        for angle in (0, -72, 72, -144, 144)
    ]


SPECS = {
    "Frigate": {
        "file": "frigate", "silhouette": "pointed dart with swept aft shoulders",
        "mounts": [[0, 0.55, -1.36], [-1.32, 0.55, 0.95], [1.32, 0.55, 0.95]],
        "drone_offsets": [],
    },
    "Destroyer": {
        "file": "destroyer", "silhouette": "split prow and twin long nacelles",
        "mounts": [[-1.32, 0.56, -0.75], [1.32, 0.56, -0.75], [0, 0.56, 1.60]],
        "drone_offsets": [[3.95, 0.10, 1.50]],
    },
    "Cruiser": {
        "file": "cruiser", "silhouette": "swept diamond with four radial hardpoints",
        "mounts": [[0, 0.56, -1.86], [-1.86, 0.56, 0], [1.86, 0.56, 0], [0, 0.56, 1.86]],
        "drone_offsets": [[4.40, 0.10, 1.35]],
    },
    "Battleship": {
        "file": "battleship", "silhouette": "blunt armored bow and broad parallel shoulders",
        "mounts": [[-1.34, 0.60, -1.33], [1.34, 0.60, -1.33], [-1.34, 0.60, 1.33], [1.34, 0.60, 1.33]],
        "drone_offsets": [[-4.65, 0.10, 0.20], [4.65, 0.10, 0.20]],
    },
    "Heavy_Battleship": {
        "file": "heavy_battleship", "silhouette": "five-point armored crown with twin stern lobes",
        "mounts": pentagon_mounts(),
        "drone_offsets": [[-4.85, 0.10, 0.65], [4.85, 0.10, 0.65], [0, 0.15, -5.25]],
    },
}


def xz_distance(a, b):
    return math.hypot(a[0] - b[0], a[2] - b[2])


def validate_layouts():
    """Conservative continuous-rotation clearance, including the drone weapons."""
    expected = {"Frigate": (3, 0), "Destroyer": (3, 1), "Cruiser": (4, 1),
                "Battleship": (4, 2), "Heavy_Battleship": (5, 3)}
    result = {}
    for name, spec in SPECS.items():
        assert (len(spec["mounts"]), len(spec["drone_offsets"])) == expected[name]
        all_mounts = spec["mounts"] + spec["drone_offsets"]
        pair_distances = [xz_distance(a, b) for a, b in itertools.combinations(all_mounts, 2)]
        minimum = min(pair_distances)
        assert minimum >= MIN_MOUNT_DISTANCE, (name, minimum)
        result[name] = {
            "hull_mount_budget": len(spec["mounts"]),
            "drone_count": len(spec["drone_offsets"]),
            "minimum_mount_center_distance": round(minimum, 6),
            "minimum_rotation_envelope_gap": round(minimum - 2 * WEAPON_RADIUS, 6),
        }
    return result


def bpy_xyz(godot_xyz):
    return godot_xyz[0], -godot_xyz[2], godot_xyz[1]


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    g.MATERIALS.clear()
    for name, (rgb, glow) in PALETTE.items():
        g.material(name, rgb, glow)


def armor(name, outline, bottom, top, parent, color="ProtoIvory", bevel=0.06):
    return g.slab(name, outline, bottom, top, color, parent, bevel)


def mirror(outline, sign):
    return [(sign * x, y) for x, y in outline]


def spine(name, stations, parent, color="ProtoHullBlue", bevel=0.08, x=0):
    return g.armor_mass(name, stations, color, parent, offset_x=x, bevel=bevel)


def engine(root, number, x, y, height=-0.06, radius=0.30):
    """Individual engine retains a stable exhaust socket for runtime effects."""
    node = g.empty("Engine%02d" % number, (x, y, height), root)
    g.cylinder("EngineCowl", (0, 0.11, 0), radius * 1.05, 0.59,
               "ProtoGraphite", node, sideways=True, vertices=12)
    g.cylinder("EngineLip", (0, -0.19, 0), radius * 1.10, 0.11,
               "ProtoNavy", node, sideways=True, vertices=12)
    g.cylinder("EngineLens", (0, -0.253, 0), radius * 0.77, 0.022,
               "ProtoEngine", node, sideways=True, vertices=12)
    g.empty("ExhaustSocket%02d" % number, (0, -0.29, 0), node)
    g.merge_under(node, "Engine%02dMesh" % number)


def canopy(hull, y, width=0.72, length=0.77, roof=0.83):
    # Kept in the central negative space rather than between close barrels.
    g.box("BridgeArmor", (0, y, roof - 0.13), (width, length, 0.26),
          "ProtoIvory", hull, 0.10)
    g.box("BridgeGlass", (0, y + length * 0.30, roof + 0.014),
          (width * 0.69, length * 0.25, 0.035), "ProtoCyan", hull, 0.015)


def add_mounts(root, hull, positions):
    for index, position in enumerate(positions, 1):
        x, y, z = bpy_xyz(position)
        # Small chamfered plinths avoid turning the silhouette into a flat slab.
        g.cylinder("SocketPlinth%02d" % index, (x, y, z - 0.092), 0.70, 0.18,
                   "ProtoGraphite", hull, vertices=8)
        g.cylinder("SocketDeck%02d" % index, (x, y, z - 0.017), 0.60, 0.034,
                   "ProtoNavy", hull, vertices=12)
        g.empty("WeaponMount%02d" % index, (x, y, z), root)


def frigate(root, hull):
    spine("DartKeel", [(-2.54, 0.85, -0.43, 0.39), (-1.78, 1.79, -0.49, 0.43),
                       (-0.82, 2.40, -0.48, 0.43), (0.38, 1.69, -0.40, 0.43),
                       (1.65, 1.04, -0.29, 0.44), (3.02, 0.12, -0.12, 0.37)], hull)
    for side in (-1, 1):
        armor("SweptShoulder", mirror([(0.73, -2.24), (1.53, -2.03), (2.48, -0.91),
              (2.15, -0.30), (1.61, -0.22), (0.78, -1.78)], side), -0.19, 0.56, hull)
        armor("ProwCheek", mirror([(0.30, 1.60), (0.94, 1.48), (0.36, 2.74),
              (0.05, 3.15)], side), -0.04, 0.60, hull, bevel=0.045)
        engine(root, 1 if side < 0 else 2, side * 0.86, -2.28, radius=0.28)
    g.box("ProwLight", (0, 2.34, 0.60), (0.13, 0.56, 0.035), "ProtoCyan", hull, 0.02)
    spine("FrigateCommandSpine", [(-2.04, 0.30, 0.42, 0.69), (-1.47, 0.42, 0.42, 0.83),
                                 (-0.32, 0.26, 0.42, 0.69), (0.33, 0.14, 0.42, 0.49)],
          hull, "ProtoIvory", 0.055)
    g.box("BridgeGlass", (0, -1.14, 0.80), (0.40, 0.19, 0.05), "ProtoCyan", hull, 0.02)
    for side in (-1, 1):
        g.box("SternEngineArmor", (side * 0.87, -2.04, 0.43), (0.56, 0.62, 0.25),
              "ProtoIvory", hull, 0.08)
        g.box("ShoulderPaint", (side * 1.95, -1.03, 0.57), (0.16, 0.34, 0.055),
              "ProtoHullBlue", hull, 0.02)


def destroyer(root, hull):
    spine("EscortKeel", [(-2.78, 0.80, -0.47, 0.44), (-2.13, 1.27, -0.53, 0.45),
                         (-0.45, 1.46, -0.49, 0.44), (1.56, 1.48, -0.34, 0.43),
                         (2.03, 0.55, -0.20, 0.40)], hull)
    for side in (-1, 1):
        spine("LongNacelle", [(-2.35, 0.41, -0.38, 0.43), (-1.54, 0.72, -0.45, 0.47),
                              (1.44, 0.69, -0.35, 0.48), (2.69, 0.28, -0.16, 0.40)],
              hull, x=side * 1.78, bevel=0.055)
        armor("ForkArmor", mirror([(1.50, -1.77), (2.28, -1.25), (2.48, 0.63),
              (2.09, 2.81), (1.61, 2.65), (1.80, 1.02), (1.67, -0.20)], side),
              -0.06, 0.60, hull, bevel=0.05)
        g.box("ForkLight", (side * 1.94, 2.11, 0.57), (0.14, 0.58, 0.06),
              "ProtoCyan", hull, 0.02)
        engine(root, 1 if side < 0 else 2, side * 1.75, -2.20, radius=0.31)
    canopy(hull, -0.12, width=0.66, length=0.72, roof=0.66)
    armor("AftCap", [(-0.90, -2.54), (0.90, -2.54), (0.58, -2.93), (-0.58, -2.93)],
          -0.12, 0.50, hull)


def cruiser(root, hull):
    spine("DiamondKeel", [(-2.89, 0.43, -0.38, 0.43), (-1.72, 1.18, -0.43, 0.44),
                          (0, 1.70, -0.47, 0.45), (1.72, 1.14, -0.37, 0.44),
                          (3.10, 0.13, -0.10, 0.37)], hull)
    for side in (-1, 1):
        armor("SweptWingCore", mirror([(0.68, -1.50), (1.58, -1.49), (3.22, -0.47),
              (3.30, 0.18), (1.55, 1.12), (0.72, 1.27)], side), -0.36, 0.43,
              hull, "ProtoHullBlue", 0.08)
        armor("WingArmor", mirror([(1.02, -1.47), (1.61, -1.44), (3.18, -0.48),
              (3.28, -0.03), (2.71, 0.24), (2.47, -0.49)], side), -0.10, 0.60, hull)
        armor("NoseArmor", mirror([(0.11, 2.39), (0.68, 2.09), (0.23, 3.13),
              (0.04, 3.29)], side), -0.08, 0.61, hull, bevel=0.04)
        g.box("WingLight", (side * 2.85, -0.42, 0.59), (0.23, 0.14, 0.045),
              "ProtoCyan", hull, 0.02)
        engine(root, 1 if side < 0 else 3, side * 1.18, -1.83, radius=0.25)
    engine(root, 2, 0, -2.77, radius=0.27)
    canopy(hull, 0, width=0.67, length=0.94, roof=0.84)
    armor("AftFin", [(-0.37, -2.53), (0.37, -2.53), (0.21, -3.03), (-0.21, -3.03)],
          -0.09, 0.57, hull, bevel=0.045)


def battleship(root, hull):
    spine("BulwarkKeel", [(-2.86, 1.42, -0.53, 0.45), (-2.16, 2.23, -0.61, 0.48),
                          (-0.65, 2.49, -0.62, 0.48), (1.51, 2.57, -0.53, 0.48),
                          (2.45, 2.18, -0.31, 0.47), (3.04, 1.17, -0.19, 0.42)], hull)
    for side in (-1, 1):
        armor("BroadShoulder", mirror([(1.98, -2.24), (2.59, -1.61), (2.96, 1.12),
              (2.57, 2.33), (2.09, 2.08), (2.22, 0.51)], side), -0.26, 0.69, hull)
        armor("BowArmor", mirror([(0.14, 2.26), (1.12, 2.18), (1.59, 2.73),
              (0.83, 3.19), (0.14, 3.19)], side), -0.10, 0.71, hull)
        armor("SternArmor", mirror([(0.59, -2.62), (1.78, -2.42), (2.03, -2.02),
              (1.16, -2.05), (0.59, -2.33)], side), -0.14, 0.63, hull)
        g.box("BowLight", (side * 0.42, 2.88, 0.70), (0.14, 0.36, 0.055),
              "ProtoCyan", hull, 0.02)
        engine(root, 1 if side < 0 else 3, side * 1.13, -2.73, radius=0.33)
    engine(root, 2, 0, -2.88, radius=0.37)
    canopy(hull, -0.11, width=0.79, length=1.04, roof=0.90)


def heavy_battleship(root, hull):
    # A narrow dark keel, broad detached-looking shoulder armor and an unmistakable
    # pointed bow replace the old uninterrupted oval tabletop. Sockets are unchanged.
    spine("CitadelKeel", [(-3.03, 1.16, -0.64, 0.42), (-2.40, 2.03, -0.80, 0.44),
                       (-1.35, 2.47, -0.78, 0.44), (-0.35, 2.38, -0.71, 0.44),
                       (0.82, 2.65, -0.65, 0.44), (1.66, 2.29, -0.52, 0.43),
                       (2.45, 1.25, -0.34, 0.42), (3.40, 0.10, -0.12, 0.35)], hull)
    for side in (-1, 1):
        armor("ForwardShoulder", mirror([(1.24, 1.12), (2.29, 1.42), (2.89, 0.73),
              (3.03, -0.20), (2.62, -0.64), (2.38, 0.28), (1.62, 0.67)], side),
              -0.24, 0.78, hull, bevel=0.10)
        armor("AftShoulder", mirror([(1.76, -0.71), (2.41, -0.84), (2.66, -1.51),
              (2.26, -2.62), (1.74, -2.98), (1.74, -2.39), (1.97, -1.71)], side),
              -0.31, 0.75, hull, bevel=0.08)
        armor("BowBlade", mirror([(0.12, 3.51), (0.87, 3.02), (1.49, 1.79),
              (1.17, 1.34), (0.80, 2.46), (0.12, 3.14)], side),
              -0.12, 0.73, hull, bevel=0.07)
        armor("SternEngineArmor", mirror([(0.39, -2.46), (0.94, -2.39), (1.06, -3.13),
              (0.47, -3.22)], side), -0.31, 0.70, hull, bevel=0.065)
        # Broad blue insert and one bright stripe establish a small-scale paint hierarchy.
        armor("ShoulderInset", mirror([(2.65, 0.56), (2.75, -0.09), (2.57, -0.25),
              (2.43, 0.42)], side), 0.60, 0.79, hull, "ProtoHullBlue", 0.025)
        g.box("BowRunningLight", (side * 0.70, 2.86, 0.73), (0.13, 0.35, 0.05),
              "ProtoCyan", hull, 0.02)
        armor("CitadelSidePanel", mirror([(0.64, -1.15), (1.12, -0.97), (1.38, -0.10),
              (1.24, 0.47), (0.67, 0.88), (0.82, -0.15)], side),
              0.32, 0.59, hull, bevel=0.065)
        # Rear exposed radiators visually separate the engine room from the gun deck.
        for y in (-2.19, -2.39, -2.59):
            g.box("AftRadiator", (side * 0.27, y, 0.49), (0.26, 0.09, 0.08),
                  "ProtoGraphite", hull, 0.02)
    spine("RaisedCitadel", [(-1.10, 0.56, 0.40, 0.67), (-0.64, 0.67, 0.42, 0.95),
                          (0.54, 0.48, 0.42, 0.89), (1.21, 0.23, 0.42, 0.65)],
          hull, "ProtoIvory", 0.08)
    g.box("BridgeGlass", (0, 0.37, 0.96), (0.57, 0.25, 0.055), "ProtoCyan", hull, 0.035)
    g.box("BridgeRoof", (0, -0.26, 1.00), (0.57, 0.55, 0.12), "ProtoHullBlue", hull, 0.06)
    for index, x in enumerate((-1.50, -0.68, 0.68, 1.50), 1):
        engine(root, index, x, -3.07, height=0.12, radius=0.34)
        g.box("EngineTopCowl", (x, -3.05, 0.41), (0.57, 0.53, 0.16),
              "ProtoGraphite", hull, 0.065)
        g.box("EngineTopVent", (x, -3.22, 0.505), (0.36, 0.13, 0.045),
              "ProtoEngine", hull, 0.025)


BUILDERS = {
    "Frigate": frigate, "Destroyer": destroyer, "Cruiser": cruiser,
    "Battleship": battleship, "Heavy_Battleship": heavy_battleship,
}


def mount_metadata(positions):
    return [{"node": "WeaponMount%02d" % (index + 1), "slot": index,
             "position": position, "rotation_axis": "Y", "forward": "-Z"}
            for index, position in enumerate(positions)]


def export(root, file_name, positions):
    bpy.context.view_layer.update()
    source = HULL_OUT / "source" / (file_name + ".blend")
    meta = g.export_asset(root, HULL_OUT / (file_name + ".glb"), source)
    span = meta["godot_aabb_max"][2] - meta["godot_aabb_min"][2]
    meta["model_span"] = round(span, 6)  # Fore-aft hull length, excluding drones.
    meta["weapon_mounts"] = mount_metadata(positions)
    assert len([obj for obj in g.descendants(root) if obj.name.startswith("WeaponMount")]) == len(positions)
    g.save_source(root, source)
    return meta


def build_hull(name, spec, check):
    reset_scene()
    root = g.empty(name + "Hull")
    hull = g.empty("Hull", parent=root)
    BUILDERS[name](root, hull)
    add_mounts(root, hull, spec["mounts"])
    g.merge_under(hull, "HullArmor")
    meta = export(root, spec["file"], spec["mounts"])
    meta.update({"hull_mount_budget": len(spec["mounts"]),
                 "silhouette": spec["silhouette"], "drone_offsets": spec["drone_offsets"],
                 "minimum_mount_center_distance": check["minimum_mount_center_distance"],
                 "minimum_rotation_envelope_gap": check["minimum_rotation_envelope_gap"]})
    return meta


def build_drone():
    reset_scene()
    root = g.empty("WeaponDrone")
    hull = g.empty("Hull", parent=root)
    armor("DroneKeel", [(0, 1.10), (-0.65, 0.57), (-0.97, -0.37), (-0.75, -1.08), (-0.26, -0.91),
          (0.26, -0.91), (0.75, -1.08), (0.97, -0.37), (0.65, 0.57)], -0.31, 0.25, hull, "ProtoHullBlue", 0.06)
    for side in (-1, 1):
        armor("DroneCheek", mirror([(0.42, -0.64), (0.82, -0.32), (0.70, 0.41),
              (0.46, 0.67), (0.53, -0.04)], side), -0.08, 0.38, hull, bevel=0.045)
        engine(root, 1 if side < 0 else 2, side * 0.67, -0.99, height=0.06, radius=0.20)
    armor("DroneProw", [(-0.31, 0.63), (0, 1.15), (0.31, 0.63)], 0.04, 0.37, hull, bevel=0.035)
    g.box("DroneLight", (0, 0.93, 0.37), (0.17, 0.14, 0.045), "ProtoCyan", hull, 0.02)
    positions = [[0, 0.46, 0]]
    add_mounts(root, hull, positions)
    g.merge_under(hull, "HullArmor")
    meta = export(root, "weapon_drone", positions)
    meta.update({"hull_mount_budget": 1, "carrier_scale": 1.0, "weapon_scale": 1.0,
                 "purpose": "independently instantiated presentation carrier"})
    return meta


def build():
    global bpy, g
    import bpy
    sys.path.insert(0, str(OUT))
    import build_ship as g

    checks = validate_layouts()
    (HULL_OUT / "source").mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    hulls = {name: build_hull(name, spec, checks[name]) for name, spec in SPECS.items()}
    drone = build_drone()
    base_manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    weapon_assets = {name: meta for name, meta in base_manifest["assets"].items() if name != "hull"}
    result = {
        "schema_version": 1, "scope": "presentation assets and authored visual socket budgets only",
        "forward": "-Z", "up": "+Y", "units": "meters", "pivot": "hull center",
        "model_span_axis": "Z", "hulls": hulls, "drone": drone,
        "weapon_assets": weapon_assets,
        "weapon_contract": {"pivot": "mount origin", "aim_node": "TurretPivot",
                            "muzzle_node": "Muzzle", "uniform_scale": 1.0,
                            "conservative_xz_rotation_radius": WEAPON_RADIUS,
                            "minimum_mount_center_distance": MIN_MOUNT_DISTANCE},
    }
    MANIFEST.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("HYBRID_BUILD_COMPLETE " + json.dumps(checks, sort_keys=True))


if __name__ == "__main__":
    if "--describe" in sys.argv:
        print(json.dumps({"layouts": SPECS, "clearance": validate_layouts()}, indent=2))
    else:
        build()
