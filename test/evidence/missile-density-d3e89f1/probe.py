"""Isolated, bounded replay; run from an existing checkout. No player save read/write.
Example: python probe.py --repo /path/space_idle --ref dbc0379 --out /tmp/density-base --mode simulation
Requires Godot and a working GUI display for the Compatibility renderer.
"""
import argparse, io, os, re, subprocess, tarfile
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--ref',required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--godot',default='godot');ap.add_argument('--mode',choices=['simulation','render150'],default='simulation');args=ap.parse_args()
area=args.out.resolve();area.mkdir(parents=True,exist_ok=True);project=area/'space-battleship'
if project.exists():raise SystemExit('Use a new output directory; no existing project is overwritten.')
paths=['space-battleship/'+x for x in ['scripts','data','dev','assets','addons','main.tscn','project.godot']]
archive=subprocess.check_output(['git','-C',str(args.repo),'archive',args.ref,*paths])
with tarfile.open(fileobj=io.BytesIO(archive)) as tf:tf.extractall(area,filter='data')
modules={'main':['advance_game_time','refresh_visible_cards','refresh_draw_layers','draw_battle','advance_projectile_visuals','projectile_visual','weapon_key','projectile_visual_index','decoration_budget'], 'battlefield':['draw_projectile_body_override','draw_projectile_fx','missile_visual_position'], 'game':['tick','tick_projectiles','advance_jewel_repair','jewel_attack','advance_jewel_repeats'], 'presented_battle_game':['tick_projectiles','advance_custom_projectile','target_point']}
for module,names in modules.items():
 p=project/'scripts'/(module+'.gd');source=p.read_text().replace('->void','-> void')
 for name in names:
  match=re.search(rf'^func {name}\((.*)\)(.*):$',source,re.M)
  if not match:continue
  params=[v.strip().split(':')[0].split('=')[0].strip() for v in match[1].split(',') if v.strip()]
  renamed=f'_density_{module}_{name}';call=renamed+'('+', '.join(params)+')';void='-> void' in match[2]
  wrapper=match[0]+'\n\tvar _started := Time.get_ticks_usec()\n\t'+(call if void else 'var _value = '+call)+'\n'
  wrapper+=f'\tEngine.get_meta("saved_perf").record("{module}.{name}",Time.get_ticks_usec()-_started)\n'
  if not void:wrapper+='\treturn _value\n'
  wrapper+='\n'+match[0].replace('func '+name+'(','func '+renamed+'(')
  source=source[:match.start()]+wrapper+source[match.end():]
 p.write_text(source)
script='density.gd' if args.mode=='simulation' else 'render150.gd'
(project/script).write_bytes(Path(__file__).with_name(script).read_bytes())
env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
 target=area/'userdata'/k;target.mkdir(parents=True,exist_ok=True);env[k]=str(target)
for label,flags in [('import',['--headless','--editor','--import','--quit']),('probe',['--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1373x883','--script','res://'+script])]:
 with (area/(label+'.log')).open('w') as log:
  result=subprocess.run([args.godot,'--path',str(project),*flags],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
 text=(area/(label+'.log')).read_text(errors='replace')
 if result.returncode or 'SCRIPT ERROR' in text or 'Parse Error' in text:raise SystemExit('Invalid run; inspect '+str(area/(label+'.log')))
filename='density.json' if args.mode=='simulation' else 'render150.json'
(area/filename).write_bytes((project/filename).read_bytes());print(area/filename)
