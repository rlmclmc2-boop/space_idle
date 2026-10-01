from pathlib import Path
import shutil,re
r=Path('/workspace/space_idle');w=r/'test/work/x10-hotspot';p=w/'project'
p.mkdir(exist_ok=True)
for d in ['scripts','data','dev','assets','addons']:shutil.copytree(r/'space-battleship'/d,p/d,dirs_exist_ok=True)
for n in ['project.godot','main.tscn']:shutil.copy2(r/'space-battleship'/n,p/n)
# Reuse imported resources; only source copies are instrumented.
if not (p/'.godot').exists():shutil.copytree(r/'test/work/chain-ricochet/project/.godot',p/'.godot',dirs_exist_ok=True)
modules={'main':['advance_game_time','refresh_visible_cards','refresh_draw_layers','draw_battle','on_event'],'game':['tick','tick_projectiles','advance_jewel_repair','sync_jewel_defence_damage','sync_enhancement_buffers','advance_planets','advance_hightech','jewel_attack','advance_jewel_repeats'],'presented_battle_game':['tick_projectiles','advance_custom_projectile'],'enhancement_branches':['advance_weapons','advance_defense']}
for module,names in modules.items():
 f=p/'scripts'/(module+'.gd');s=f.read_text().replace('->void','-> void')
 for name in names:
  m=re.search(rf'^func {name}\((.*)\)(.*):$',s,re.M)
  if not m:raise RuntimeError(module+'.'+name)
  params=[v.strip().split(':')[0].split('=')[0].strip() for v in m[1].split(',') if v.strip()]
  new=f'_x10_{module}_{name}';call=new+'('+', '.join(params)+')';void='-> void' in m[2]
  indent=' ' if module=='enhancement_branches' else '\t'
  wrapper=m[0]+'\n'+indent+'var _started := Time.get_ticks_usec()\n'+indent+(call if void else 'var _value = '+call)+'\n'
  wrapper+=indent+f'Engine.get_meta("x10_meter").record("{module}.{name}",Time.get_ticks_usec()-_started)\n'
  if not void:wrapper+=indent+'return _value\n'
  wrapper+='\n'+m[0].replace('func '+name+'(','func '+new+'(')
  s=s[:m.start()]+wrapper+s[m.end():]
 f.write_text(s)
shutil.copy2(w/'probe.gd',p/'probe.gd')
