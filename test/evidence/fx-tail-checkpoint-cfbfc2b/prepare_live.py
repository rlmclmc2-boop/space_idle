"""Stage an isolated real-save FX sampler; never open the original save for writing.
Use the same Godot executable as the game. Copies a save explicitly supplied by the user.
No save bytes, original user paths or credentials are included in provenance JSON.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);ap.add_argument('--save',type=Path,required=True);ap.add_argument('--godot',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--prepare-only',action='store_true');a=ap.parse_args()
source=a.project.resolve();save=a.save.resolve();area=a.out.resolve();engine=a.godot.resolve();here=Path(__file__).resolve().parent
assert source.is_dir() and save.is_file() and engine.is_file()
if area.exists():raise SystemExit('Use a new output directory; existing files are never overwritten.')
if area.is_relative_to(source):raise SystemExit('Choose an output directory outside the original project.')
area.mkdir(parents=True);project=area/'project';project.mkdir();private=area/'userdata';private.mkdir()
save_bytes=save.read_bytes()
for name in ['scripts','data','dev','assets','addons']:shutil.copytree(source/name,project/name)
for name in ['project.godot','main.tscn']:shutil.copy2(source/name,project/name)
paths=['scripts/game.gd','scripts/enhancement_branches.gd','scripts/battlefield.gd','dev/toon_ship/missile_vfx.gd','dev/toon_ship/pulse_vfx.gd','dev/diagnostics/frame_sample.gd','data/game_data.json']
provenance={'original_sha256':{n:hashlib.sha256((project/n).read_bytes()).hexdigest() for n in paths},'probe':'fx-tail-wall-v1'}
subprocess.run([sys.executable,str(here/'install_fx.py'),str(project)],check=True)
for name in ['live_fx_sample.gd','fx_tail_meter.gd']:shutil.copy2(here/name,project/name)
provenance['instrumented_sha256']={n:hashlib.sha256((project/n).read_bytes()).hexdigest() for n in paths}
(project/'fx-provenance.json').write_text(json.dumps(provenance,indent=2))
env=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
 directory=private/key;directory.mkdir();env[key]=str(directory)
# Resolve the engine's actual platform/feature-dependent user directory before starting gameplay.
(project/'fx_user_dir.gd').write_text('extends SceneTree\nfunc _initialize():\n print("FX_USER_DIR:"+OS.get_user_data_dir())\n quit()\n')
r=subprocess.run([str(engine),'--headless','--path',str(project),'--script','res://fx_user_dir.gd'],env=env,capture_output=True,text=True,timeout=30)
lines=[line[len('FX_USER_DIR:'):] for line in r.stdout.splitlines() if line.startswith('FX_USER_DIR:')]
if r.returncode or len(lines)!=1:raise SystemExit('Cannot resolve isolated save directory; no gameplay started.')
user_dir=Path(lines[0]).resolve()
if not user_dir.is_relative_to(private):raise SystemExit('Engine did not honor private userdata environment; stopped before loading the save.')
user_dir.mkdir(parents=True,exist_ok=True);(user_dir/'progress.json').write_bytes(save_bytes);del save_bytes
for label,flags in [('import',['--headless','--editor','--import','--quit']),('check',['--headless','--script','res://live_fx_sample.gd','--check-only'])]:
 with (area/(label+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run([str(engine),'--path',str(project),*flags],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 text=(area/(label+'.log')).read_text(encoding='utf-8',errors='replace')
 if r.returncode or 'SCRIPT ERROR' in text or 'Parse Error' in text:raise SystemExit('Preflight failed; see '+str(area/(label+'.log')))
(area/'launch-info.json').write_text(json.dumps({'engine':str(engine),'project':str(project),'private_env':{k:env[k] for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']}},indent=2))
print('Private project:',project,'\nReports:',project/'.runtime',flush=True)
if not a.prepare_only:
 with (area/'live.log').open('w',encoding='utf-8') as log:subprocess.run([str(engine),'--path',str(project),'--script','res://live_fx_sample.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
