"""Short real-main-scene CPU/render probe. No player save or production data writes.

Examples:
  python test/whole_game_perf.py --label before --ref 32991cc --rich
  python test/whole_game_perf.py --label after --rich
  python test/whole_game_perf.py --label max --rich --max --headless
  python test/whole_game_perf.py --label live --rich --realtime --pages 0,8
Use --instrument only for attribution, not final before/after frame comparisons.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import sys

from saved_game_perf import MODULES, instrument

ROOT = Path(__file__).resolve().parent.parent
PARTS = ('scripts', 'shaders', 'tools', 'data', 'config_excel', 'assets', 'addons', 'dev', 'project.godot', 'main.tscn')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--godot', default=shutil.which('godot') or 'godot')
    parser.add_argument('--ref', help='Read this Git snapshot instead of current source')
    parser.add_argument('--reuse', type=Path, help='Reuse this runner\'s isolated import cache')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--rich', action='store_true')
    parser.add_argument('--enemies', type=int, default=3, choices=(3, 15))
    parser.add_argument('--reactor-level', type=int, default=1)
    parser.add_argument('--balance', type=float, default=1e80)
    parser.add_argument('--check-pages', action='store_true', help='Check affected page interactions after all measurements')
    parser.add_argument('--capture', action='store_true', help='Capture after measurement; readback excluded from timings')
    parser.add_argument('--max', action='store_true', dest='max_quote')
    parser.add_argument('--realtime', action='store_true')
    parser.add_argument('--instrument', action='store_true')
    parser.add_argument('--pages', default='0,4,1,2,6,8')
    parser.add_argument('--frames', type=int, default=60)
    parser.add_argument('--galaxy-work', choices=('complete', 'idle', 'active'), default='complete', help='Same valid developing city with no crew or one actual assigned crew')
    parser.add_argument('--galaxy-steady', action='store_true', help='Settle presentation-only traffic staggering on page 8')
    args = parser.parse_args()
    assert 1 <= args.frames <= 600
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
    # Same verified native runtime and writer-lock capability as test/run.py.
    sys.path.insert(0, str(ROOT / 'tools'))
    from play_main import verified_bundle, DESCRIPTOR
    bundle, _, _ = verified_bundle(ROOT)
    (project / 'bin').mkdir(exist_ok=True)
    shutil.copy2(bundle, project / 'bin/space_native.dll')
    (project / 'space_native.gdextension').write_text(DESCRIPTOR, encoding='utf-8')
    shutil.copy2(ROOT / '太空战舰.xlsx', area / '太空战舰.xlsx')
    shutil.copy2(ROOT / 'test/whole_game_perf.gd', project / 'probe.gd')
    shutil.copy2(ROOT / 'test/fixtures/galaxy_1_complete.json', project / 'galaxy_fixture.json')
    (project / '.runtime').mkdir(exist_ok=True)
    if args.instrument:
        MODULES.update({
            'battlefield': ['_process', 'draw_battle', 'draw_vertical_battle_hud', '_draw_muzzle_cues'],
            'presented_ship_view': ['set_loadout', 'set_pose', 'apply_parameters', 'set_hull'],
            'presented_battle_game': ['tick', 'tick_projectiles'],
            'galaxy_map': ['_process', 'refresh', 'asset', 'select', 'build_city', 'refresh_city_routes', 'prepare_frame', 'prepare_core', 'prepare_slot', 'refresh_slot'],
            'galaxy_panel': ['refresh', 'refresh_detail'],
            'galaxy_city_structure': ['configure'],
            'galaxy_runtime': ['prepare_advance', 'advance', 'flush_pending', 'publish'],
            'galaxy_system': ['preview_advance', 'prepare_region', 'commit_region', 'prepare_income'],
            'galaxy_region': ['predict_advance', 'commit_prediction', 'advance', 'sync_map', 'view', 'revision_due'],
            'galaxy_city_modules': ['bake'],
            'attribute_projection': ['configuration_inputs', 'stat_inputs', 'slot', 'stat', 'jewel_equipment_stat'],
            'compiled_combat_rules': ['compile'],
            'native_execution_session': ['prepare_galaxy_refit', 'commit_galaxy_refit'],
            'enhancement_panel': ['refresh'],
        })
        MODULES['game'] += ['enhancement_protection_status', 'enhancement_module_protection_capacity',
                            'enhancement_effects', 'max_upgrade_amount_slot', 'can_upgrade_slot']
        MODULES['equipment_tab'] += ['refresh_affordability', 'update_card_cost', 'equipment_item']
        MODULES['planet_panel'] += ['add_card', 'ensure_card_content', 'refresh_card', '_apply_selection']
        MODULES['main'] += ['select_system']
        for module in MODULES:
            path = project / 'scripts' / (module + '.gd')
            # Module-specific names preserve superclass dispatch in the real scene.
            code = instrument(path.read_text(encoding='utf-8').replace('->void', '-> void'), module)
            path.write_text(code.replace('_perf_original_', '_perf_' + module + '_original_').expandtabs(1), encoding='utf-8')
    env = os.environ.copy()
    for key, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'), ('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        env[key] = str(area / 'userdata' / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(PERF_GALAXY_WORK=args.galaxy_work, PERF_CHECK_PAGES=str(int(args.check_pages)), PERF_ENEMIES=str(args.enemies), PERF_REACTOR_LEVEL=str(args.reactor_level), PERF_BALANCE=str(args.balance), PERF_CAPTURE=str(int(args.capture)), PERF_RICH=str(int(args.rich)), PERF_MAX=str(int(args.max_quote)), PERF_REALTIME=str(int(args.realtime)), PERF_PAGES=args.pages, PERF_FRAMES=str(args.frames), PERF_GALAXY_STEADY=str(int(args.galaxy_steady)))
    print('Evidence:', area, flush=True)
    engine = [args.godot, '--path', str(project)]
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    with (area / (args.label + '-import.log')).open('w', encoding='utf-8') as log:
        subprocess.run([*engine, '--headless', '--editor', '--import', '--quit'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True, startupinfo=startup)
    log_path = area / (args.label + '.log')
    with log_path.open('w', encoding='utf-8') as log:
        result = subprocess.run([*engine, *(['--headless'] if args.headless else []), '--audio-driver', 'Dummy', '--resolution', '1373x883', '--disable-vsync', '--script', 'res://probe.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180, startupinfo=startup)
    text = log_path.read_text(encoding='utf-8', errors='replace')
    rows = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ROW ')]
    environment = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ENV ')]
    expected = 1 if args.max_quote else len(args.pages.split(','))
    report = {'options': {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}, 'exit': result.returncode, 'environment': environment, 'rows': rows, 'page_checks': [json.loads(line[7:]) for line in text.splitlines() if line.startswith('CHECKS ')]}
    (area / (args.label + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Exit:', result.returncode, 'Rows:', len(rows), '/', expected, 'Log:', log_path)
    unexpected_errors = [line for line in text.splitlines() if 'ERROR:' in line and line != 'ERROR: Failed to read the root certificate store.']
    if result.returncode or len(rows) != expected or 'SCRIPT ERROR' in text or unexpected_errors:
        print(text[-4000:])
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
