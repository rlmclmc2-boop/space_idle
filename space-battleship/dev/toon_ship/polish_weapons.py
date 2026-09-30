"""Build the four independent, small-scale toy weapon presentation assets.

This is a presentation-only pass. Roots, pivot/muzzle names and muzzle transforms
match build_ship.py. Run after the legacy generator to restore polished weapons.
The generator does not write the hulls or either manifest. Its JSON report supplies
the asset metadata for the owning manifest without creating another authority.

blender --background --factory-startup --python-exit-code 1 --python \
    dev/toon_ship/polish_weapons.py -- --report /tmp/weapon-polish.json
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT))
from build_ship import (  # Shared geometry/export helpers; no legacy build call.
    MATERIALS, box, cylinder, descendants, empty, export_asset, material,
    merge_under, save_source, slab,
)

MUZZLES = {
    "pulse_laser": {"Muzzle": (0, 0.82, 0.43)},
    "missile": {"Muzzle": (-0.34, 0.52, 0.48), "Muzzle02": (0.34, 0.52, 0.48)},
    "cannon": {"Muzzle": (0, 1.11, 0.42)},
    "long_laser": {"Muzzle": (0, 0.76, 0.48)},
}


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    MATERIALS.clear()
    # Matte broad fields and one readable identifier per weapon. Avoid detail
    # smaller than a few pixels in the actual battlefield presentation.
    material("ProtoIvory", (0.79, 0.81, 0.78))
    material("ProtoNavy", (0.019, 0.049, 0.070))
    material("ProtoGraphite", (0.11, 0.19, 0.23))
    material("ProtoCyan", (0.035, 0.57, 0.66), 0.22)
    material("WeaponCopper", (0.59, 0.28, 0.105))
    material("WeaponAmber", (0.91, 0.52, 0.14))
    material("WeaponMissileRed", (0.53, 0.085, 0.065))


def pulse(turret):
    # A short, broad wedge contrasts with the sustained laser's open fork.
    slab("PulseChassis", [(-0.59, -0.39), (0.59, -0.39),
         (0.47, 0.35), (0, 0.61), (-0.47, 0.35)],
         0.24, 0.56, "ProtoNavy", turret, 0.055)
    for side in (-1, 1):
        slab("PulseShoulder", [(side * 0.18, -0.35), (side * 0.57, -0.35),
             (side * 0.44, 0.30), (side * 0.23, 0.45)],
             0.35, 0.65, "ProtoIvory", turret, 0.045)
    cylinder("EmitterRoot", (0, 0.41, 0.43), 0.265, 0.30,
             "ProtoNavy", turret, True, 12)
    cylinder("EnergyBarrel", (0, 0.66, 0.43), 0.20, 0.24,
             "ProtoGraphite", turret, True, 12)
    cylinder("EmitterLens", (0, 0.79, 0.43), 0.15, 0.025,
             "ProtoCyan", turret, True, 12)
    box("PulseEnergyTrack", (0, 0.065, 0.66), (0.24, 0.67, 0.055),
        "ProtoCyan", turret, 0.023)


def missile(turret):
    # Two separated broad bays remain legible at the real 20–30 px scale.
    box("PodCradle", (0, 0, 0.28), (1.26, 1.08, 0.30),
        "ProtoNavy", turret, 0.09)
    for x in (-0.34, 0.34):
        box("MissileBay", (x, -0.055, 0.48), (0.51, 1.02, 0.35),
            "ProtoIvory", turret, 0.085)
        box("LaunchOpening", (x, 0.475, 0.48), (0.35, 0.04, 0.19),
            "ProtoNavy", turret, 0.017)
        box("BayWell", (x, 0.17, 0.65), (0.28, 0.43, 0.03),
            "ProtoNavy", turret, 0.026)
        box("ReadyIndicator", (x, -0.305, 0.655), (0.27, 0.10, 0.025),
            "WeaponAmber", turret, 0.012)
    box("MissileRedSpine", (0, -0.10, 0.58), (0.13, 0.72, 0.12),
        "WeaponMissileRed", turret, 0.036)


def cannon(turret):
    # Graphite body and a single copper/amber breech band distinguish kinetics
    # from the two cyan energy weapons without increasing the barrel reach.
    box("GunHousing", (0, -0.13, 0.42), (1.10, 0.87, 0.47),
        "ProtoGraphite", turret, 0.12)
    box("RearArmor", (0, -0.39, 0.647), (0.72, 0.23, 0.025),
        "ProtoIvory", turret, 0.055)
    box("CopperBreech", (0, -0.035, 0.647), (0.80, 0.23, 0.025),
        "WeaponCopper", turret, 0.035)
    box("AmberBreech", (0, -0.005, 0.658), (0.46, 0.12, 0.025),
        "WeaponAmber", turret, 0.025)
    cylinder("BarrelRoot", (0, 0.30, 0.42), 0.24, 0.30,
             "WeaponCopper", turret, True, 12)
    cylinder("Barrel", (0, 0.67, 0.42), 0.14, 0.62,
             "ProtoNavy", turret, True, 12)
    box("MuzzleBrake", (0, 0.98, 0.42), (0.40, 0.21, 0.29),
        "ProtoGraphite", turret, 0.055)
    box("Bore", (0, 1.092, 0.42), (0.21, 0.018, 0.12),
        "ProtoNavy", turret, 0)


def long_laser(turret):
    box("BeamCapacitor", (0, -0.18, 0.40), (0.70, 1.00, 0.42),
        "ProtoGraphite", turret, 0.09)
    for x in (-0.405, 0.405):
        box("BeamFork", (x, 0.19, 0.46), (0.25, 1.22, 0.39),
            "ProtoIvory", turret, 0.055)
    box("BeamChannel", (0, 0.22, 0.48), (0.27, 0.92, 0.15),
        "ProtoNavy", turret, 0.025)
    # The visible cyan rail is on top of the channel, not hidden beneath the
    # surrounding forks in an orthographic overhead view.
    box("SustainedEnergyRail", (0, 0.225, 0.565), (0.15, 0.87, 0.035),
        "ProtoCyan", turret, 0.018)
    box("BeamLens", (0, 0.71, 0.48), (0.20, 0.045, 0.13),
        "ProtoCyan", turret, 0.015)
    box("RearCap", (0, -0.51, 0.616), (0.49, 0.21, 0.04),
        "ProtoIvory", turret, 0.035)
    box("CapacitorLight", (0, -0.36, 0.621), (0.28, 0.13, 0.035),
        "ProtoCyan", turret, 0.016)


def validate(root, turret, kind):
    bpy.context.view_layer.update()
    assert root.name == kind + "Weapon"
    assert tuple(root.location) == (0, 0, 0)
    assert turret.name == "TurretPivot" and turret.parent == root
    assert tuple(turret.location) == (0, 0, 0)
    for name, expected in MUZZLES[kind].items():
        obj = next(obj for obj in turret.children if obj.name == name)
        assert max(abs(obj.location[i] - expected[i]) for i in range(3)) < 1e-6
    points = [obj.matrix_world @ Vector(vertex) for obj in descendants(root)
              if obj.type == "MESH" for vertex in obj.bound_box]
    radius = math.hypot(max(abs(p.x) for p in points), max(abs(p.y) for p in points))
    assert radius <= 1.24, (kind, radius)
    return round(radius, 6)


def review_render(kind, destination):
    """Optional source-asset review only; actual-size acceptance is in Godot."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.view_settings.view_transform = "Standard"
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (1.8, -3.2, 8.0)
    camera.rotation_euler = (Vector((0, 0.2, 0.3)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.15
    scene.camera = camera
    destination.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(destination / (kind + ".png"))
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    parser.add_argument("--review-dir", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    report = {"assets": {}, "weapon_contract": {}, "generator": "polish_weapons.py"}
    builders = {"pulse_laser": pulse, "missile": missile, "cannon": cannon, "long_laser": long_laser}
    (OUT / "weapons").mkdir(exist_ok=True)
    (OUT / "source").mkdir(exist_ok=True)
    for kind, builder in builders.items():
        clear_scene()
        root = empty(kind + "Weapon")
        turret = empty("TurretPivot", parent=root)
        cylinder("RotationBearing", (0, 0, 0.045), 0.40, 0.09,
                 "ProtoNavy", root, vertices=12)
        box("RotationYoke", (0, 0, 0.15), (0.76, 0.65, 0.19),
            "ProtoGraphite", turret, 0.055)
        builder(turret)
        for name, location in MUZZLES[kind].items():
            empty(name, location, turret)
        merge_under(turret, "WeaponArmor")
        radius = validate(root, turret, kind)
        blend_path = OUT / "source" / (kind + ".blend")
        report["assets"][kind] = export_asset(root, OUT / "weapons" / (kind + ".glb"), blend_path)
        report["weapon_contract"][kind] = {
            "root": root.name, "pivot": "TurretPivot", "origin": [0, 0, 0],
            "godot_muzzles": {name: [p[0], p[2], -p[1]] for name, p in MUZZLES[kind].items()},
            "conservative_xz_rotation_radius": radius,
        }
        # Save only this independent asset, never a preview camera or lights.
        save_source(root, blend_path)
        if args.review_dir:
            review_render(kind, args.review_dir)
    text = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
