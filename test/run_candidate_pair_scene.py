"""Parent-controlled real scene probe. Defaults to preflight, never long-runs.

No dependency installation, live saves, source Excel or production JSON writes.
The supplied candidate JSON is projected into a private database in memory.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True,type=Path)
    p.add_argument('--options',type=Path,default=ROOT/'test/candidate_pair_options.json')
    p.add_argument('--phase',choices=['preflight','battle'],default='preflight')
    p.add_argument('--groups',nargs='+')
    p.add_argument('--weapons',nargs='+',default=['cannon'])
    p.add_argument('--upgrades',nargs='+',type=int,default=[0])
    p.add_argument('--seeds',nargs='+',type=int,default=[1701])
    p.add_argument('--wall-timeout',type=int,default=120)
    p.add_argument('--headless',action='store_true')
    a=p.parse_args()
    work=ROOT/'test/work';work.mkdir(exist_ok=True)
    area=Path(tempfile.mkdtemp(prefix='candidate-pair-',dir=work))
    game=area/'space-battleship';game.mkdir()
    source=ROOT/'space-battleship'
    for name in ['scripts','tools','data','config_excel','assets','dev','addons']:
        if (source/name).is_dir():shutil.copytree(source/name,game/name)
    for name in ['project.godot','main.tscn','level_editor.tscn']:
        shutil.copy2(source/name,game/name)
    qa=game/'qa';qa.mkdir()
    shutil.copy2(ROOT/'test/test_candidate_pair_scene.gd',qa/'probe.gd')
    shutil.copy2(ROOT/'test/progression/scene_driver.gd',qa/'scene_driver.gd')
    options=json.loads(a.options.read_text(encoding='utf8'))
    options.update(phase=a.phase,weapons=a.weapons,upgrades=a.upgrades,seeds=a.seeds)
    if a.groups:options['groups']=a.groups
    options['output']=str(area/'results.jsonl')
    input_path=area/'options.json';input_path.write_text(json.dumps(options,ensure_ascii=False),encoding='utf8')
    env=os.environ.copy()
    for key,name in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
        env[key]=str(area/'userdata'/name);Path(env[key]).mkdir(parents=True,exist_ok=True)
    env['SPACE_BATTLESHIP_PYTHON']=os.sys.executable
    print(f'Private evidence directory: {area}',flush=True)
    commands=[['--headless','--editor','--import','--quit'],(['--headless'] if a.headless else [])+['--script','res://qa/probe.gd','--',str(input_path)]]
    for i,flags in enumerate(commands):
        command=[str(a.godot.resolve()),'--path',str(game)]+flags
        with (area/f'phase-{i}.log').open('w',encoding='utf8') as log:
            r=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=a.wall_timeout)
        print((area/f'phase-{i}.log').read_text(encoding='utf8',errors='replace')[-6000:])
        if r.returncode:return r.returncode
    rows=[json.loads(line) for line in (area/'results.jsonl').read_text(encoding='utf8').splitlines()]
    rejected=sum(row['status']=='geometry_rejected' for row in rows)
    print(f'{len(rows)} rows; {rejected} geometry rejections. No balance acceptance claim.')
    return 3 if rejected else 0

if __name__=='__main__':raise SystemExit(main())
