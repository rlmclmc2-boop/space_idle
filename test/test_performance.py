"""One-off Phase 9 launcher: copies inputs, instruments only copies, repeats fixed probes.

Run directly from the workspace. Engine processes use a copied project and redirected
player directories. --label names evidence, never changes scenario parameters.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

WORKSPACE = Path(__file__).resolve().parent.parent
SOURCE = WORKSPACE / 'space-battleship'
FUNCTIONS = {
    'main': ['_process', 'build_ui', 'on_event', 'refresh_scientists', 'refresh_hightech_progress',
             'prune_resource_samples'],
    'game': ['tick', 'tick_projectiles', 'targets', 'missile_target', 'weapon_entries', 'stat',
             'scientist_purchase', 'scientist_cost', 'can_generate_scientist', 'max_upgrade_amount_slot',
             'can_upgrade_slot', 'hightech_description', 'reactor_energy', 'resource_minute_total',
             'prune_resource_samples', 'save_progress', 'upgrade_reactor', 'advance_hightech',
             'settle_offline_resources'],
    'database': ['equip', 'ship', 'max_equipment_level', 'enemy_weapon'],
}


def instrument(text, module):
    for name in FUNCTIONS[module]:
        pattern = rf'^func {name}\((.*)\)(.*):$'
        match = re.search(pattern, text, re.M)
        assert match, (module, name)
        args = [x.strip().split(':')[0].split('=')[0].strip() for x in match[1].split(',') if x.strip()]
        call = f'_p9_original_{name}({", ".join(args)})'
        void = '-> void' in match[2]
        extra = ''
        if name == 'scientist_purchase': extra = '\tif amount < 0: Engine.get_meta("phase9").count("scientist_MAX")\n'
        if name == 'targets': extra = '\tEngine.get_meta("phase9").count("target_sorts")\n'
        wrapper = match[0] + '\n\tvar _p9_started := Time.get_ticks_usec()\n' + extra
        wrapper += '\t' + (call if void else 'var _p9_value = ' + call) + '\n'
        wrapper += f'\tEngine.get_meta("phase9").record("{module}.{name}", Time.get_ticks_usec()-_p9_started)\n'
        if not void: wrapper += '\treturn _p9_value\n'
        wrapper += '\n' + match[0].replace('func '+name+'(', 'func _p9_original_'+name+'(')
        text = text[:match.start()] + wrapper + text[match.end():]
    if module == 'game':
        text = text.replace('for shot in projectiles.duplicate():\n', 'for shot in projectiles.duplicate():\n\t\tEngine.get_meta("phase9").count("projectile_visits")\n')
        text = text.replace('for other in projectiles:\n', 'for other in projectiles:\n\t\t\tEngine.get_meta("phase9").count("missile_occupancy_visits")\n')
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--runs', type=int, default=3)
    args = parser.parse_args()
    work = WORKSPACE / 'test/work'
    work.mkdir(exist_ok=True)
    area = Path(tempfile.mkdtemp(prefix='phase9-'+args.label+'-', dir=work))
    subprocess.run(['icacls',str(area),'/inheritance:e'],check=True,stdout=subprocess.DEVNULL)
    game = area/'space-battleship'
    for name in ('scripts','data','assets'):
        shutil.copytree(SOURCE/name,game/name,ignore=shutil.ignore_patterns('.import_state.json','__pycache__'))
    for name in ('project.godot','main.tscn'):
        shutil.copy2(SOURCE/name,game/name)
    (game/'.runtime').mkdir()
    shutil.copy2(WORKSPACE/'test/phase9_probe.gd',game/'phase9_probe.gd')
    originals={name:(game/'scripts'/f'{name}.gd').read_text(encoding='utf-8') for name in FUNCTIONS}
    hashes={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest()
            for name in ('scripts','data') for p in (SOURCE/name).iterdir() if p.is_file()}
    env=os.environ.copy()
    env['APPDATA']=str(area/'userdata/roaming'); env['LOCALAPPDATA']=str(area/'userdata/local')
    env['PYTHONUTF8']='1'
    for key in ('APPDATA','LOCALAPPDATA'): Path(env[key]).mkdir(parents=True)
    engine=SOURCE/'engine/Godot_v4.7.2-stable_win64.exe'
    def run(command,label):
        with (area/(label+'.log')).open('w',encoding='utf-8') as log:
            result=subprocess.run([str(engine),'--path',str(game),*command],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        log=(area/(label+'.log')).read_text(encoding='utf-8',errors='replace')
        if result.returncode or 'SCRIPT ERROR' in log or 'Parse Error' in log:
            raise RuntimeError(label+' exit='+str(result.returncode)+'\n'+log[-6000:])
    print('Evidence:',area,flush=True)
    reports=[]
    for mode in ('raw','instrumented'):
        for name,text in originals.items():
            (game/'scripts'/f'{name}.gd').write_text(instrument(text,name) if mode=='instrumented' else text,encoding='utf-8')
        run(['--headless','--editor','--import','--quit'],mode+'-import')
        for repeat in range(args.runs):
            # Raw rendered frames and instrumented rendered frames use identical viewport and fixed timestep.
            run(['--disable-vsync','--resolution','1440x810','--script','res://phase9_probe.gd'],f'{mode}-{repeat}')
            report=json.loads((game/'.runtime/performance.json').read_text(encoding='utf-8'))
            report.update(mode=mode,repeat=repeat)
            reports.append(report)
            (area/f'{mode}-{repeat}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
            print(mode,repeat,'complete',flush=True)
    (area/'results.json').write_text(json.dumps({'hashes':hashes,'runs':reports},ensure_ascii=False,indent=2),encoding='utf-8')
    assert all(hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()==h for p,h in hashes.items()), 'Formal input/source changed during probe'
    print('Completed:',area,flush=True)


if __name__=='__main__': main()
