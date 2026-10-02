"""Stage only read-only source data/art into an isolated Godot review project."""
import argparse
from pathlib import Path
import os
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=['board', 'small', 'recovery', 'weapons', 'coverage'], default='board')
    parser.add_argument('--gray', action='store_true', help='Render grayscale directly in Godot')
    parser.add_argument('--frames', type=int, default=0)
    parser.add_argument('--gap', type=float, default=2.0, help='Visible clearance in screen pixels')
    parser.add_argument('--layer-gap', type=float, default=2.5, help='Visible clearance between protection layers')
    args = parser.parse_args()
    if args.gap < 0 or args.layer_gap < 0:
        parser.error('Protection clearances must be nonnegative')
    here = Path(__file__).resolve().parent
    source = here.parents[1]
    output = args.output.resolve()
    stage = output / '.preview-project'
    stage.mkdir(parents=True, exist_ok=True)
    for name in ['data/game_data.json', 'data/ship_weapon_visuals.json', 'assets/fonts/NotoSansSC.ttf']:
        target = stage / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, target)
    hulls = Path('assets/ships/enemy/toon_v1')
    (stage / hulls).mkdir(parents=True, exist_ok=True)
    for hull in (source / hulls).glob('*.png'):
        shutil.copy2(hull, stage / hulls / hull.name)
    shutil.copy2(here / 'preview.gd', stage / 'preview.gd')
    (stage / 'scripts').mkdir(exist_ok=True)
    shutil.copy2(source / 'scripts/enemy_protection_geometry.gd', stage / 'scripts/enemy_protection_geometry.gd')
    (stage / 'project.godot').write_text('''config_version=5
[application]
config/name="Enemy recognition review"
run/main_scene="res://preview.tscn"
[display]
window/size/viewport_width=1373
window/size/viewport_height=883
[rendering]
renderer/rendering_method="gl_compatibility"
environment/defaults/default_clear_color=Color(0.03,0.05,0.1,1)
''' + f'\n[visuals]\nenemy_protection_gap_pixels={args.gap}\nenemy_protection_layer_gap_pixels={args.layer_gap}\n', encoding='utf-8')
    (stage / 'preview.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://preview.gd" id="1"]
[node name="Review" type="Node2D"]
script = ExtResource("1")
''', encoding='utf-8')
    env = os.environ.copy()
    for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        env[key] = str(stage / '.user' / key)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    subprocess.run([args.godot, '--headless', '--path', str(stage), '--editor', '--import'], env=env, check=True)
    command = [args.godot, '--path', str(stage), '--audio-driver', 'Dummy', '--', '--mode='+args.mode,
               '--output='+str(output), '--frames='+str(args.frames)]
    if args.gray:
        command.append('--gray')
    subprocess.run(command, env=env, check=True, timeout=60)


if __name__ == '__main__':
    main()
