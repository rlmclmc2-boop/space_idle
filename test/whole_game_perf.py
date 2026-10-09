"""Short real-main-scene CPU/render probe. No player save or production data writes.

Examples:
  python test/whole_game_perf.py --label before --ref 32991cc --rich
  python test/whole_game_perf.py --label after --rich
  python test/whole_game_perf.py --label max --rich --max --headless
  python test/whole_game_perf.py --label live --rich --realtime --pages 0,8
Use --instrument only for attribution, not final before/after frame comparisons.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from saved_game_perf import MODULES, instrument

ROOT = Path(__file__).resolve().parent.parent
PARTS = ('scripts', 'data', 'assets', 'addons', 'dev', 'project.godot', 'main.tscn')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--godot', default=shutil.which('godot') or 'godot')
    parser.add_argument('--ref', help='Read this Git snapshot instead of current source')
    parser.add_argument('--reuse', type=Path, help='Reuse this runner\'s isolated import cache')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--rich', action='store_true')
    parser.add_argument('--balance', type=float, default=1e80)
    parser.add_argument('--capture', action='store_true', help='Capture after measurement; readback excluded from timings')
    parser.add_argument('--max', action='store_true', dest='max_quote')
    parser.add_argument('--realtime', action='store_true')
    parser.add_argument('--instrument', action='store_true')
    parser.add_argument('--pages', default='0,4,1,2,6,8')
    parser.add_argument('--frames', type=int, default=60)
    parser.add_argument('--warmup-frames', type=int, default=15)
    parser.add_argument('--render-inventory', action='store_true', help='Live ship representation and viewport visibility inventory after sampling')
    parser.add_argument('--galaxy-steady', action='store_true', help='Settle presentation-only traffic staggering on page 8')
    parser.add_argument('--retained-galaxy-probe', action='store_true', help='Experimental frozen color/depth retention proof; requires --rich --pages 8, never production acceptance')
    parser.add_argument('--retained-galaxy-boundaries', action='store_true', help='Camera/building fallback and dock-edge diagnostic; requires --rich --pages 8')
    args = parser.parse_args()
    retained = args.retained_galaxy_probe or args.retained_galaxy_boundaries
    if args.retained_galaxy_probe and args.retained_galaxy_boundaries:
        parser.error('choose one retained diagnostic')
    if retained and (not args.rich or args.pages != '8' or args.headless or args.instrument or args.realtime or args.max_quote):
        parser.error('retained proof requires graphical --rich --pages 8 without instrumentation, realtime or max quotes')
    assert 1 <= args.frames <= 600
    assert 1 <= args.warmup_frames <= 600
    work = ROOT / 'test/work'
    work.mkdir(exist_ok=True)
    area = args.reuse.resolve() if args.reuse else Path(tempfile.mkdtemp(prefix='whole-perf-', dir=work))
    assert area.parent == work.resolve() and area.name.startswith('whole-perf-')
    project = area / 'space-battleship'
    source = ROOT / 'space-battleship'
    if args.ref:
        archive = area / 'input.tar'
        with archive.open('wb') as output:
            subprocess.run(['git', 'archive', args.ref, *['space-battleship/' + p for p in PARTS]], cwd=ROOT, stdout=output, check=True)
        source = area / 'source/space-battleship'
        with tarfile.open(archive) as package:
            package.extractall(area / 'source', filter='data')
        archive.unlink()
    project.mkdir(exist_ok=True)
    for part in PARTS:
        origin, target = source / part, project / part
        if origin.is_dir():
            shutil.copytree(origin, target, dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.blend', '*.blend1', '__pycache__'))
        else:
            shutil.copy2(origin, target)
    probe = 'retained_galaxy_boundaries.gd' if args.retained_galaxy_boundaries else 'retained_galaxy_probe.gd' if retained else 'whole_game_perf.gd'
    shutil.copy2(ROOT / 'test' / probe, project / 'probe.gd')
    if args.retained_galaxy_boundaries:
        shutil.copy2(ROOT / 'test/retained_galaxy_probe.gd', project / 'retained_galaxy_probe.gd')
    if retained:
        for shader in ('retained_galaxy_color.gdshader', 'retained_galaxy_depth.gdshader'):
            shutil.copy2(ROOT / 'test' / shader, project / shader)
    shutil.copy2(ROOT / 'test/fixtures/galaxy_1_complete.json', project / 'galaxy_fixture.json')
    (project / '.runtime').mkdir(exist_ok=True)
    if args.instrument:
        MODULES.update({
            'battlefield': ['_process', 'draw_battle', 'draw_vertical_battle_hud', '_draw_muzzle_cues'],
            'presented_ship_view': ['set_loadout', 'set_pose', 'apply_parameters', 'set_hull'],
            'presented_battle_game': ['tick', 'tick_projectiles'],
            'galaxy_map': ['_process', 'refresh', 'asset'],
            'enhancement_panel': ['refresh'],
        })
        MODULES['game'] += ['enhancement_protection_status', 'enhancement_module_protection_capacity',
                            'enhancement_effects', 'max_upgrade_amount_slot', 'can_upgrade_slot']
        MODULES['equipment_tab'] += ['refresh_affordability', 'update_card_cost']
        for module in MODULES:
            path = project / 'scripts' / (module + '.gd')
            # Module-specific names preserve superclass dispatch in the real scene.
            code = instrument(path.read_text(encoding='utf-8').replace('->void', '-> void'), module)
            path.write_text(code.replace('_perf_original_', '_perf_' + module + '_original_'), encoding='utf-8')
    env = os.environ.copy()
    for key, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'), ('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        env[key] = str(area / 'userdata' / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(PERF_BALANCE=str(args.balance), PERF_CAPTURE=str(int(args.capture)), PERF_RICH=str(int(args.rich)), PERF_MAX=str(int(args.max_quote)), PERF_REALTIME=str(int(args.realtime)), PERF_PAGES=args.pages, PERF_FRAMES=str(args.frames), PERF_WARMUP_FRAMES=str(args.warmup_frames), PERF_RENDER_INVENTORY=str(int(args.render_inventory)), PERF_GALAXY_STEADY=str(int(args.galaxy_steady)))
    if retained:
        env['SPACE_IDLE_FLAT_SHIPS'] = '0'
    print('Evidence:', area, flush=True)
    engine = [args.godot, '--path', str(project)]
    with (area / (args.label + '-import.log')).open('w', encoding='utf-8') as log:
        subprocess.run([*engine, '--headless', '--editor', '--import', '--quit'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
    log_path = area / (args.label + '.log')
    with log_path.open('w', encoding='utf-8') as log:
        result = subprocess.run([*engine, *(['--headless'] if args.headless else []), '--audio-driver', 'Dummy', '--resolution', '1373x883', '--disable-vsync', '--script', 'res://probe.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    text = log_path.read_text(encoding='utf-8', errors='replace')
    rows = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ROW ')]
    environment = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ENV ')]
    expected = 0 if args.retained_galaxy_boundaries else 2 if args.retained_galaxy_probe else 1 if args.max_quote else len(args.pages.split(','))
    measured_files = ['probe.gd', 'project.godot', 'main.tscn', 'data/game_data.json', 'galaxy_fixture.json',
                      *['scripts/' + name for name in ('main.gd', 'battlefield.gd', 'game.gd', 'presented_battle_game.gd',
                                                       'presented_ship_view.gd', 'ship_body_baker.gd', 'flat_ship_compositor.gd',
                                                       'flat_ship_compositor.gdshader', 'galaxy_map.gd', 'galaxy_city_modules.gd')]]
    if retained:
        measured_files += ['retained_galaxy_color.gdshader', 'retained_galaxy_depth.gdshader']
    if args.retained_galaxy_boundaries:
        measured_files += ['retained_galaxy_probe.gd']
    report = {'options': {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
              'source_ref': subprocess.check_output(['git', 'rev-parse', args.ref or 'HEAD'], cwd=ROOT, text=True).strip(),
              'runtime_sha256': {name: hashlib.sha256((project / name).read_bytes()).hexdigest() for name in measured_files},
              'flat_candidate_requested': env.get('SPACE_IDLE_FLAT_SHIPS') == '1',
              'software_renderer_environment': {key: env.get(key) for key in ('LP_NUM_THREADS', 'GALLIUM_DRIVER')},
              'exit': result.returncode, 'environment': environment, 'rows': rows,
              'boundaries': [line for line in text.splitlines() if line.startswith('BOUNDARY_')]}
    boundary_failures = []
    if args.retained_galaxy_boundaries:
        events = {}
        for line in report['boundaries']:
            name, payload = line.split(' ', 1)
            if payload.startswith('{'):
                event = json.loads(payload)
                events[name] = event
                if event.get('profile_equal') is False:
                    boundary_failures.append(name + ': unexpected profile mutation')
        for name in ('WHEEL', 'PAN', 'BUILDING_FIXTURE', 'UPGRADE_START', 'UPGRADE_FINISH', 'REMOVE_FIXTURE', 'BUILD_START'):
            if events.get('BOUNDARY_' + name, {}).get('active') is not False:
                boundary_failures.append(name + ': live fallback missing')
        if not events.get('BOUNDARY_MOVING', {}).get('transport_moved'):
            boundary_failures.append('transport failed to move')
        if events.get('BOUNDARY_UPGRADE_FINISH', {}).get('level') != 5:
            boundary_failures.append('authority upgrade completion missing')
        if not events.get('BOUNDARY_BUILD_START', {}).get('built'):
            boundary_failures.append('authority build attempt missing')
    report['boundary_failures'] = boundary_failures
    (area / (args.label + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Exit:', result.returncode, 'Rows:', len(rows), '/', expected, 'Log:', log_path)
    if boundary_failures or (args.retained_galaxy_boundaries and len(report['boundaries']) != 14) or result.returncode or len(rows) != expected or 'SCRIPT ERROR' in text or 'ERROR:' in text or (args.retained_galaxy_probe and any(not row.get('profile_equal') for row in rows)):
        print(text[-4000:])
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
