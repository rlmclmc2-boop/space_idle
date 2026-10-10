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
import signal
import time
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from saved_game_perf import MODULES, instrument
from perf_process import WindowsJob

ROOT = Path(__file__).resolve().parent.parent
PARTS = ('scripts', 'data', 'assets', 'addons', 'dev', 'project.godot', 'main.tscn')


def run_guarded(command, env, log_path, timeout=180):
    """Own and clear the whole child process tree on errors, timeout or interruption."""
    failed = False
    with log_path.open('w', encoding='utf-8') as output:
        options = {'start_new_session': True} if os.name != 'nt' else {}
        job = WindowsJob()
        try:
            process = subprocess.Popen(command, env=env, stdout=output, stderr=subprocess.STDOUT, **options)
            job.assign(process)
        except BaseException:
            if 'process' in locals() and process.poll() is None:
                process.kill()
                process.wait()
            job.close()
            raise
        started = time.monotonic()
        try:
            while process.poll() is None:
                time.sleep(.2)
                text = log_path.read_text(encoding='utf-8', errors='replace')
                if any(marker in text for marker in ('SCRIPT ERROR', 'CHECKPOINT_FAILURE', 'handle_crash', 'ERROR:')) or time.monotonic()-started > timeout:
                    failed = True
                    break
        finally:
            if os.name == 'nt':
                job.close()
                if process.poll() is None:
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                # The group is private to this launch. Clear workers even if the
                # leader exited; never kill unrelated Godot/editor processes.
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                if os.name != 'nt':
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                else:
                    process.kill()
                process.wait()
            if os.name != 'nt':
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
    return process.returncode if process.returncode else (1 if failed else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--battle-only', action='store_true', help='Private-copy noncombat tick isolation; static modifiers retained, fixed-workload throughput only')
    parser.add_argument('--dynamic-replay', action='store_true', help='Record final native visible state in RAM and replay R0; diagnostic only, source recording is not clean timing')
    parser.add_argument('--native-check', action='store_true', help='Diagnostic same-frame native painter/pinned-reference comparison; not clean timing')
    parser.add_argument('--boundary-check', action='store_true', help='Diagnostic canonical/read-model spatial and display contract equality; not clean timing')
    parser.add_argument('--phase-account', action='store_true', help='Private-copy exclusive broad-phase attribution; diagnostic overhead, not clean throughput')
    parser.add_argument('--godot', default=shutil.which('godot') or 'godot')
    snapshots=parser.add_mutually_exclusive_group()
    snapshots.add_argument('--checkpoint-round2', type=Path, help='Exact authorized QA7/group4/Frigate snapshot')
    snapshots.add_argument('--checkpoint-round4', type=Path, help='Exact authorized QA20/group2/Destroyer snapshot')
    parser.add_argument('--sustain-test-health', action='store_true', help='After the real fleet is generated, hold test health; explicitly synthetic, never natural-play acceptance')
    parser.add_argument('--checkpoint-wave', type=int, default=0, choices=range(10), help='QA-only authored wave selection; requires sustained test health, reported as synthetic')
    parser.add_argument('--test-missile-burst', type=int, default=0, choices=(0,256,1024), help='One synthetic burst of the QA ship actual missile weapon; no natural-load claim')
    parser.add_argument('--gpu-profile', action='store_true', help='Native GPU stage averages; timing-query overhead, not final frame comparison')
    parser.add_argument('--render-cost', action='store_true', help='Diagnostic native setup and per-viewport CPU/GPU wall times; never clean throughput')
    parser.add_argument('--ref', help='Read this Git snapshot instead of current source')
    parser.add_argument('--reuse', type=Path, help='Reuse this runner\'s isolated import cache')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--submission-mode', choices=('full','no-submit','no-presentation','empty'), default='full', help='Isolated upper-bound diagnostic: no-submit keeps full game/UI processing but disables RenderingServer loop; empty detaches the scene and measures blank window, not comparable gameplay')
    parser.add_argument('--rendering-method', choices=('gl_compatibility','mobile','forward_plus'), help='Isolated renderer comparison; never changes production project settings')
    parser.add_argument('--rich', action='store_true')
    parser.add_argument('--missile-loadout', action='store_true', help='Rich fixture selects eight actual missile slots; production cadence and parameters unchanged')
    parser.add_argument('--organic-economy', action='store_true', help='Rich fixture omits artificial per-frame wealth mutation; actual production economy still runs')
    parser.add_argument('--authored-stage', type=int, default=0, choices=range(21), help='Rich fixture uses the first actual authored wave, with test health')
    parser.add_argument('--missile-profile', action='store_true', help='Static missile VFX CPU and command attribution; diagnostic overhead, never clean throughput')
    parser.add_argument('--stress-enemies', type=int, default=3, choices=range(1,16), help='Synthetic sustained enemies; requires --rich, never a natural player claim')
    parser.add_argument('--balance', type=float, default=1e80)
    parser.add_argument('--capture', action='store_true', help='Capture after measurement; readback excluded from timings')
    parser.add_argument('--max', action='store_true', dest='max_quote')
    parser.add_argument('--realtime', action='store_true')
    parser.add_argument('--instrument', action='store_true')
    parser.add_argument('--cpu-peaks', action='store_true', help='Per-frame CPU phase attribution with limited outer timers; never clean throughput')
    parser.add_argument('--focused-draw', action='store_true', help='Detailed draw/layout attribution; implies instrumentation, never a clean throughput result')
    parser.add_argument('--pages', default='0,4,1,2,6,8')
    parser.add_argument('--frames', type=int, default=60)
    parser.add_argument('--warmup-frames', type=int, default=15)
    parser.add_argument('--render-inventory', action='store_true', help='Live ship representation and viewport visibility inventory after sampling')
    parser.add_argument('--galaxy-steady', action='store_true', help='Settle presentation-only traffic staggering on page 8')
    args = parser.parse_args()
    if args.dynamic_replay and not args.battle_only:
        parser.error('dynamic-replay requires battle-only')
    if args.native_check and (not args.battle_only or args.dynamic_replay or args.phase_account or args.boundary_check or args.instrument):
        parser.error('native-check requires battle-only without other instrumentation')
    if args.boundary_check and (not args.battle_only or args.dynamic_replay or args.phase_account or args.instrument):
        parser.error('boundary-check requires battle-only and cannot be combined with replay or other instrumentation')
    if args.phase_account and (not args.battle_only or args.dynamic_replay or args.instrument or args.cpu_peaks or args.focused_draw):
        parser.error('phase-account requires only battle-only, without replay or overlapping instrumenters')
    if args.battle_only and (not args.rich or args.pages != '0' or args.realtime or args.headless or args.checkpoint_round2 or args.checkpoint_round4 or args.instrument):
        parser.error('battle-only requires fixed-step graphical rich page0')
    if (args.missile_loadout or args.authored_stage or args.organic_economy) and not args.rich:
        parser.error('missile-loadout/authored-stage require the explicitly synthetic rich fixture')
    if args.submission_mode != 'full' and (args.pages != '0' or args.realtime or args.headless or args.checkpoint_round2 or args.checkpoint_round4):
        parser.error('submission diagnostics require graphical fixed-step synthetic --pages 0, without checkpoints')
    freeze_diagnostic=any(os.environ.get(key)=='1' for key in ('PERF_FREEZE_CONTACT_CANVAS','PERF_FREEZE_SHIP_BUFFER','PERF_FREEZE_CONTACT_BITMAP'))
    if freeze_diagnostic and (not args.rich or args.pages!='0' or args.realtime or args.headless or args.checkpoint_round2 or args.checkpoint_round4):
        parser.error('visible freeze diagnostics require graphical fixed-step rich page0')
    if os.environ.get('PERF_FREEZE_CONTACT_BITMAP')=='1' and os.environ.get('PERF_FREEZE_CONTACT_CANVAS')!='1':
        parser.error('enemy bitmap diagnostic requires frozen contact Canvas')
    checkpoint_source=args.checkpoint_round2 or args.checkpoint_round4
    checkpoint = checkpoint_source is not None
    checkpoint_stage=7 if args.checkpoint_round2 else 20
    checkpoint_group=4 if args.checkpoint_round2 else 2
    if args.checkpoint_wave and not (checkpoint and args.sustain_test_health):
        parser.error('checkpoint-wave requires an exact QA checkpoint and sustained test health')
    if args.test_missile_burst and not (checkpoint and args.sustain_test_health):
        parser.error('test-missile-burst requires an exact QA checkpoint and sustained test health')
    if args.checkpoint_wave:
        checkpoint_group=args.checkpoint_wave
    if args.sustain_test_health and not checkpoint:
        parser.error("sustain-test-health requires an exact QA checkpoint")
    if checkpoint and not args.ref:
        parser.error('checkpoint requires a pinned --ref')
    if checkpoint and (args.rich or args.pages != '0' or args.headless or args.realtime or args.max_quote):
        parser.error('checkpoint requires graphical --pages 0 without synthetic/rich/realtime/max modes')
    expected_hash='bdc03716a07667d6067e22ddbbba6b4afadfbc0f4e4cc6abd534aab3dd6f770e' if args.checkpoint_round2 else 'd11614ad44bb800fd1252381437ae773f349b1763ef95ff76c96878970cee387'
    if checkpoint and hashlib.sha256(checkpoint_source.read_bytes()).hexdigest() != expected_hash:
        parser.error('checkpoint must be the exact authorized QA snapshot')
    assert 1 <= args.frames <= 600
    assert 1 <= args.warmup_frames <= 600
    work = ROOT / 'test/work'
    work.mkdir(exist_ok=True)
    area = args.reuse.resolve() if args.reuse else Path(tempfile.mkdtemp(prefix='whole-perf-', dir=work))
    assert area.parent == work.resolve() and area.name.startswith('whole-perf-')
    if os.name == 'nt':
        subprocess.run(['icacls', str(area), '/inheritance:e'], check=True, stdout=subprocess.DEVNULL)
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
    if checkpoint:
        shutil.copy2(ROOT / ('test/checkpoint_round2.gd' if args.checkpoint_round2 else 'test/checkpoint_round4.gd'), project / 'probe.gd')
        shutil.copy2(ROOT / 'test/checkpoint_scene_cost.gd', project / 'checkpoint_scene_cost.gd')
        shutil.copy2(checkpoint_source, project / 'checkpoint.json')
    else:
        shutil.copy2(ROOT / 'test/whole_game_perf.gd', project / 'probe.gd')
    if os.environ.get('PERF_FREEZE_CONTACT_CANVAS') == '1':
        contact_path=project / 'scripts/retained_enemy_contacts.gd'
        if not contact_path.exists() or 'retained_contacts_enabled' not in (project / 'scripts/battlefield.gd').read_text(encoding='utf-8'):
            parser.error('freeze diagnostic requires retained Canvas candidate')
        contact=contact_path.read_text(encoding='utf-8')
        contact=contact.replace('var frame:Dictionary={}', 'var frame:Dictionary={}\nvar frozen_once:=false')
        contact=contact.replace('func sync(offset:Vector2,boss:bool)->void:', 'func sync(offset:Vector2,boss:bool)->void:\n if frozen_once:return\n if Engine.has_meta("saved_perf") and Engine.get_meta("saved_perf").enabled:frozen_once=true')
        contact_path.write_text(contact,encoding='utf-8')
    if not checkpoint and os.environ.get('PERF_RETENTION_PROFILE') != '1':
        probe_path=project / 'probe.gd'
        probe=probe_path.read_text(encoding='utf-8')
        begin=probe.index(' func draw_enemy_hull_and_status(')
        end=probe.index(' var last_process_us',begin)
        probe_path.write_text(probe[:begin]+probe[end:],encoding='utf-8')
    shutil.copy2(ROOT / 'test/fixtures/galaxy_1_complete.json', project / 'galaxy_fixture.json')
    if args.battle_only:
        from battle_render_diagnostic import prepare
        prepare(project, ROOT, args.dynamic_replay)
    phase_wrapped=[]
    if args.phase_account:
        from battle_phase_account import prepare as prepare_phases
        phase_wrapped=prepare_phases(project,ROOT)
    if args.boundary_check:
        if not (project/'scripts/battle_read_model.gd').exists():parser.error('boundary check requires structural candidate')
        shutil.copy2(ROOT/'test/battle_boundary_check.gd',project/'battle_boundary_check.gd')
        probe_path=project/'probe.gd';probe=probe_path.read_text(encoding='utf-8')
        probe=probe.replace('func run():','func run():\n var boundary_check=preload("res://battle_boundary_check.gd").new()')
        probe=probe.replace('   await RenderingServer.frame_post_draw','   boundary_check.check(scene)\n   await RenderingServer.frame_post_draw')
        probe=probe.replace('  row.retention_counts=','  row.boundary_check=boundary_check.report()\n  row.retention_counts=')
        probe_path.write_text(probe,encoding='utf-8')
    if args.native_check:
        shutil.copy2(ROOT/'test/retained_native_check.gd',project/'retained_native_check.gd')
        for module in ['retained_enemy_contacts','enemy_recognition_visual']:
            reference=subprocess.check_output(['git','-c','safe.directory=*','show','6144e357:space-battleship/scripts/'+module+'.gd'],cwd=ROOT)
            (project/('reference_'+module+'.gd')).write_bytes(reference)
        probe_path=project/'probe.gd';probe=probe_path.read_text(encoding='utf-8')
        probe=probe.replace('func run():','func run():\n var native_check=preload("res://retained_native_check.gd").new()')
        probe=probe.replace('   await RenderingServer.frame_post_draw\n   if i>=warmup:', '   await RenderingServer.frame_post_draw\n   await native_check.after_draw(scene,i,root)\n   if i>=warmup:')
        probe=probe.replace('  row.retention_counts=', '  row.native_check=native_check.report()\n  row.retention_counts=')
        probe_path.write_text(probe,encoding='utf-8')
    (project / '.runtime').mkdir(exist_ok=True)
    if args.focused_draw:args.instrument=True
    if args.missile_profile:args.instrument=True
    if args.cpu_peaks:args.instrument=True
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
        if args.focused_draw:
            MODULES['main'] += ['draw_enemy_hull_and_status', 'enemy_render_width_at_y', 'enemy_frontline_y_limit', 'enemy_component_pose', 'enemy_weapon_angle', 'enemy_recognition_geometry', 'enemy_weapon_components', 'enemy_render_position', 'damage_text_enemy_bottom', 'damage_text_enemy_bounds', 'draw_enemy_weapon_components', 'damage_text_rect']
            MODULES['battlefield'] += ['battle_meter','draw_enemy_hull_and_status','enemy_status_layout','draw_encounter_backdrop','enemy_hull_light']
            MODULES['enemy_recognition_visual']=['geometry','draw_weapon','draw_protection','state','draw_attack_deck']
        if args.missile_profile:
            MODULES['battlefield']+=['draw_projectile_body_override','draw_projectile_fx','missile_visual_position']
            MODULES['main']+=['projectile_visual']
        if args.cpu_peaks:
            MODULES.clear()
            MODULES.update({
                'main':['advance_game_time','advance_turrets','advance_projectile_visuals','on_event','queue_damage_number','flush_damage_numbers','refresh_visible_cards','refresh_navigation','refresh_draw_layers','weapon_launch','visual_muzzle','enemy_shot_mount','equipment_display_snapshot','module_tooltip'],
                'game':['tick','tick_projectiles','jewel_attack','jewel_fire','fire','hit_enemy','hit_player','advance_jewel_repair','enemy_weapon_offset','launch_player_attack','combat_entry','player_weapon_offset','enhancement_effects','module_effects','equipment_damage','module_damage','attack_from_snapshot','new_attack_instance','jewel_equipment_stat','jewel_critical','plan_attack_repeats','player_weapon_row'],
                'battlefield':['weapon_launch','enemy_target_point','enemy_render_position'],
                'presented_battle_game':['launch_player_attack','target_point','prepare_projectile','tick_projectiles'],
                'equipment_tab':['refresh','refresh_stats','refresh_affordability','refresh_detail','refresh_live','update_card_cost','card_level_text','rate_value','rate_title','textured_panel_style','equipment_choices','stat_projection'],
                'equipment_card':['refresh','refresh_options','fit_stat_text'],
                'equipment_style_tiles':['panel_style'],
            })
        for module in MODULES:
            path = project / 'scripts' / (module + '.gd')
            # Module-specific names preserve superclass dispatch in the real scene.
            source = path.read_text(encoding='utf-8')
            if args.cpu_peaks and module == 'presented_battle_game':
                start = source.index('func target_point(')
                stop = source.index('func tick_projectiles(', start)
                source = source[:start] + """func target_point(target:Dictionary)->Vector2:
	var began=Time.get_ticks_usec()
	var point:Vector2=target_provider.call(target) if target_provider.is_valid() else Vector2(target.x,target.y)
	var elapsed=Time.get_ticks_usec()-began
	var measure=Engine.get_meta("saved_perf")
	if measure.enabled:
		var uid=int(target.get("uid",-1))
		var previous:Dictionary=measure.target_seen.get(uid,{})
		var role="first"
		if not previous.is_empty() and is_same(previous.entity,target):role="repeat_equal" if previous.point==point else "repeat_changed"
		measure.target_seen[uid]={"entity":target,"point":point}
		measure.record("probe.target_"+role,elapsed)
		if measure.steering_active:
			var earlier:Dictionary=measure.steering_seen.get(uid,{})
			var steering_role="first"
			if not earlier.is_empty() and is_same(earlier.entity,target):steering_role="repeat_equal" if earlier.point==point else "repeat_changed"
			measure.steering_seen[uid]={"entity":target,"point":point}
			measure.record("probe.steering_target_"+steering_role,elapsed)
	return point

""" + source[stop:]
                source = source.replace('func tick_projectiles(dt:float)->void:\n', 'func tick_projectiles(dt:float)->void:\n\tEngine.get_meta("saved_perf").target_seen.clear()\n', 1)
                source = source.replace('\tif bool(shot.hostile) or not bool(shot.get("prototype_missile",false)):return false', '\tif bool(shot.hostile) or not bool(shot.get("prototype_missile",false)):\n\t\tEngine.get_meta("saved_perf").steering_seen.clear();Engine.get_meta("saved_perf").steering_active=false;return false\n\tEngine.get_meta("saved_perf").steering_active=true', 1)
                source = source.replace('\t\t\tevent.emit("projectile_impact",', '\t\t\tEngine.get_meta("saved_perf").steering_seen.clear();Engine.get_meta("saved_perf").steering_active=false\n\t\t\tevent.emit("projectile_impact",', 1)
                source = source.replace('func _retire_missile(shot:Dictionary,reason:String,coast:bool)->void:\n', 'func _retire_missile(shot:Dictionary,reason:String,coast:bool)->void:\n\tEngine.get_meta("saved_perf").steering_seen.clear();Engine.get_meta("saved_perf").steering_active=false\n', 1)
                source = source.replace('\tsuper.tick_projectiles(dt)\n\nfunc prepare_projectile', '\tsuper.tick_projectiles(dt)\n\tEngine.get_meta("saved_perf").steering_seen.clear();Engine.get_meta("saved_perf").steering_active=false\n\nfunc prepare_projectile', 1)
            code = instrument(source.replace('->void', '-> void'), module)
            path.write_text(code.replace('_perf_original_', '_perf_' + module + '_original_'), encoding='utf-8')
        if args.missile_profile:
            path=project/'dev/toon_ship/missile_vfx.gd'
            code=path.read_text(encoding='utf-8')
            MODULES['missile_vfx']=['flight','trail','flash','impact','retire']
            # Static draw helpers share the same meter; retain static dispatch.
            import re
            current=''
            lines=[]
            for line in code.splitlines():
                match=re.match(r'static func (\w+)\(',line)
                if match:current=match[1]
                if 'surface.draw_' in line:
                    command=re.search(r'surface\.(draw_\w+)',line)[1]
                    record=f'Engine.get_meta("saved_perf").record("cmd.missile_vfx.{current}.{command}",0);'
                    line=line.replace('surface.'+command,record+'surface.'+command,1)
                lines.append(line)
            code='\n'.join(lines)+'\n'
            code=instrument(code.replace('static func ','func ').replace('->void','-> void'),'missile_vfx')
            code=code.replace('\nfunc ','\nstatic func ').replace('_perf_original_','_perf_missile_original_')
            path.write_text(code,encoding='utf-8')
    env = os.environ.copy()
    for key, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'), ('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        env[key] = str(area / 'userdata' / folder)
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    env.update(PERF_SUSTAIN_TEST_HEALTH=str(int(args.sustain_test_health)), PERF_STRESS_ENEMIES=str(args.stress_enemies), PERF_BALANCE=str(args.balance), PERF_CAPTURE=str(int(args.capture)), PERF_RICH=str(int(args.rich)), PERF_MAX=str(int(args.max_quote)), PERF_REALTIME=str(int(args.realtime)), PERF_PAGES=args.pages, PERF_FRAMES=str(args.frames), PERF_WARMUP_FRAMES=str(args.warmup_frames), PERF_RENDER_INVENTORY=str(int(args.render_inventory)), PERF_GALAXY_STEADY=str(int(args.galaxy_steady)))
    env['PERF_MISSILE_LOADOUT']=str(int(args.missile_loadout))
    env['PERF_ORGANIC_ECONOMY']=str(int(args.organic_economy))
    env['PERF_AUTHORED_STAGE']=str(args.authored_stage)
    env['PERF_RENDER_COST']=str(int(args.render_cost))
    env['PERF_SUBMISSION_MODE']=args.submission_mode
    env['PERF_CPU_PEAKS']=str(int(args.cpu_peaks))
    if checkpoint:
        env['SPACE_IDLE_FLAT_SHIPS'] = '0'
        env['PERF_CHECKPOINT_WAVE'] = str(args.checkpoint_wave)
        env['PERF_TEST_MISSILE_BURST'] = str(args.test_missile_burst)
    if checkpoint:
        for key in ('PERF_BALANCE', 'PERF_RICH', 'PERF_MAX'):
            env.pop(key, None)
    print('Evidence:', area, flush=True)
    engine = [args.godot, '--path', str(project)]
    import_log = area / (args.label + '-import.log')
    imported = run_guarded([*engine, '--headless', '--audio-driver', 'Dummy', '--editor', '--import', '--quit'], env, import_log)
    if imported:
        print('Import failed; no measurement started:', import_log)
        return 1
    log_path = area / (args.label + '.log')
    command = [*engine, *(['--headless'] if args.headless else []), '--audio-driver', 'Dummy', '--resolution', '1373x883', '--disable-vsync']
    if args.rendering_method:
        command += ['--rendering-method',args.rendering_method]
    if args.gpu_profile:
        command.append('--gpu-profile')
    command += ['--script', 'res://probe.gd']
    result_code = run_guarded(command, env, log_path)
    text = log_path.read_text(encoding='utf-8', errors='replace')
    rows = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ROW ')]
    environment = [json.loads(line[4:]) for line in text.splitlines() if line.startswith('ENV ')]
    expected = 1 if checkpoint or args.max_quote else len(args.pages.split(','))
    measured_files = ['probe.gd', 'project.godot', 'main.tscn', 'data/game_data.json', 'galaxy_fixture.json',
                      *['scripts/' + name for name in ('main.gd', 'battlefield.gd', 'game.gd', 'presented_battle_game.gd',
                                                       'presented_ship_view.gd', 'ship_body_baker.gd', 'flat_ship_compositor.gd',
                                                       'flat_ship_compositor.gdshader', 'galaxy_map.gd', 'galaxy_city_modules.gd')]]
    if checkpoint:
        measured_files += ['checkpoint_scene_cost.gd', 'checkpoint.json']
    measured_files += ['dev/toon_ship/missile_vfx.gd','scripts/enemy_recognition_visual.gd']
    for native_file in ['scripts/resident_stroke_geometry.gd','scripts/resident_stroke.gdshader']:
        if (project/native_file).exists():measured_files.append(native_file)
    if (project/'scripts/battle_read_model.gd').exists():measured_files += ['scripts/battle_read_model.gd','scripts/retained_enemy_contacts.gd']
    if args.battle_only:measured_files += ['battle_scope.gd']
    if args.dynamic_replay:measured_files += ['native_render_tape.gd']
    if args.phase_account:measured_files += ['exclusive_phase_ledger.gd']
    if args.native_check:measured_files += ['retained_native_check.gd','reference_retained_enemy_contacts.gd','reference_enemy_recognition_visual.gd']
    if args.boundary_check:measured_files += ['battle_boundary_check.gd']
    report = {'options': {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
              'harness_ref': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'driver_sha256': {name:hashlib.sha256((ROOT/'test'/name).read_bytes()).hexdigest() for name in ['whole_game_perf.py','battle_render_diagnostic.py','battle_phase_account.py']},
              'source_ref': subprocess.check_output(['git', 'rev-parse', args.ref or 'HEAD'], cwd=ROOT, text=True).strip(),
              'runtime_sha256': {name: hashlib.sha256((project / name).read_bytes()).hexdigest() for name in measured_files},
              'flat_candidate_requested': env.get('SPACE_IDLE_FLAT_SHIPS') == '1',
              'phase_wrapped':phase_wrapped,
              'software_renderer_environment': {key: env.get(key) for key in ('LP_NUM_THREADS', 'GALLIUM_DRIVER')},
              'exit': result_code, 'environment': environment, 'rows': rows,
              'entry_rows': [json.loads(line[10:]) for line in text.splitlines() if line.startswith('ENTRY_ROW ')],
              'gpu_profile_lines': [line for line in text.splitlines() if line.startswith('GPU PROFILE') or ('ms' in line and line.lstrip().startswith('-'))],
              'gpu_profile_scope': 'Header total is last captured GPU frame; stages are approximately1second averages; no stageP95. Query overhead; keep separate from clean throughput.',
              'boundaries': [line for line in text.splitlines() if line.startswith('BOUNDARY_')]}
    boundary_failures = []
    if args.native_check and (not rows or not rows[0].get('native_check',{}).get('frames')):
        boundary_failures.append('native-check snapshots missing; no visual acceptance')
    if args.dynamic_replay:
        r0_lines=[line[7:] for line in text.splitlines() if line.startswith('R0_ROW ')]
        if len(r0_lines)!=1:
            boundary_failures.append('R0 missing or aborted; no accepted rendering comparison')
        else:
            r0=json.loads(r0_lines[0])
            (area/(args.label+'-r0.json')).write_text(json.dumps(r0,ensure_ascii=False,indent=2),encoding='utf-8')
            report['r0_summary']={key:value for key,value in r0.items() if key not in ('audit','visible_counts')}
            if not r0.get('equivalence_accepted'):
                boundary_failures.append('R0 visual equivalence gate failed; no performance conclusion')
    if checkpoint and rows:
        row = rows[0]
        if not row.get('source_save_unchanged') or row.get('save_enabled') or row.get('flat_enabled'):
            boundary_failures.append('checkpoint source/save/default invariant failed')
        if row.get('sample_frames') != args.frames or any(value != checkpoint_stage for value in row.get('stages', [])) or any(value != checkpoint_group for value in row.get('groups', [])) or any(value != 3 for value in row.get('states', [])):
            boundary_failures.append('checkpoint encounter changed or sample count mismatched; not the pinned combat window')
    if args.gpu_profile and not report['gpu_profile_lines']:
        boundary_failures.append('native GPU profile unavailable; no GPU stage evidence')
    report['boundary_failures'] = boundary_failures
    (area / (args.label + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Exit:', result_code, 'Rows:', len(rows), '/', expected, 'Log:', log_path)
    if boundary_failures or result_code or len(rows) != expected or 'SCRIPT ERROR' in text or 'ERROR:' in text:
        print(text[-4000:])
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
