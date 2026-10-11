"""Inject bounded RAM counts in owned QA source; production untouched."""
import re,shutil
from pathlib import Path
def prepare(project:Path,root:Path):
 shutil.copy2(root/'test/membership_diagnostic.gd',project/'membership_diagnostic.gd')
 sites=[]
 for name in ['game.gd','presented_battle_game.gd','drone_combat_effects.gd']:
  path=project/'scripts'/name;source=path.read_text(encoding='utf-8');lines=[];function=''
  for number,line in enumerate(source.splitlines(),1):
   if line.startswith('func '):function=line[5:line.index('(')]
   def replace(match):
    array,method,value=match.groups();key=f'{name}:{function}:{number}:{array}:{method}'
    sites.append(key)
    return f'Engine.get_meta("membership_meter").'+('contains' if method=='has' else 'erase')+f'({array},{value},"{key}")'
   line=re.sub(r'(?<![\w.])((?:g\.)?(?:projectiles|enemies))\.(has|erase)\((\w+(?:\.\w+)?)\)',replace,line)
   if name=='game.gd' and 'enemies.any(func(enemy):return is_same(enemy,target))' in line:
    key=f'{name}:{function}:{number}:identity_any';sites.append(key)
    line=line.replace('enemies.any(func(enemy):return is_same(enemy,target))',f'Engine.get_meta("membership_meter").identity_contains(enemies,target,"{key}")')
   if 'projectiles = projectiles.filter(' in line:
    key=f'{name}:{function}:{number}:filter_input';sites.append(key)
    indent=line[:len(line)-len(line.lstrip())]
    lines.append(indent+f'Engine.get_meta("membership_meter").pass_size(projectiles,"{key}")')
   lines.append(line)
  source='\n'.join(lines)+'\n'
  if name=='game.gd':
   at=source.index('func tick(dt: float)');end=source.index('\nfunc ',at+1)
   chunk=source[at:end].replace('\tif paused:return','\tif paused:return\n\tEngine.get_meta("membership_meter").begin_tick(dt)',1)
   source=source[:at]+chunk+source[end:]
   source=source.replace('\tvar pending := projectiles.duplicate()','\tvar pending := projectiles.duplicate()\n\tEngine.get_meta("membership_meter").note_snapshot(pending.size())',1)
   original='\t\tif (index>=projectiles.size() or not is_same(projectiles[index],shot)) and not '
   replacement='\t\tvar index_mismatch:=index>=projectiles.size() or not is_same(projectiles[index],shot)\n\t\tEngine.get_meta("membership_meter").note_index(index_mismatch)\n\t\tif index_mismatch and not '
   assert original in source;source=source.replace(original,replacement,1)
  if name=='presented_battle_game.gd':
   source=source.replace('\t\tsuper.tick(step)','\t\tsuper.tick(step)\n\t\tEngine.get_meta("membership_meter").finish_tick()',1)
  path.write_text(source,encoding='utf-8')
 probe=project/'probe.gd';source=probe.read_text(encoding='utf-8')
 source=source.replace(' Engine.set_meta("saved_perf",meter)',' Engine.set_meta("saved_perf",meter)\n Engine.set_meta("membership_meter",preload("res://membership_diagnostic.gd").new())',1)
 source=source.replace('sample_started=true;wall_start=', 'sample_started=true;Engine.get_meta("membership_meter").reset();wall_start=',1)
 source=source.replace('  row.enemy_canvas_frozen=', '  row.membership_counts=Engine.get_meta("membership_meter").report()\n  row.enemy_canvas_frozen=',1)
 source=source.replace(' Engine.remove_meta("saved_perf")',' Engine.remove_meta("membership_meter")\n Engine.remove_meta("saved_perf")',1)
 probe.write_text(source,encoding='utf-8');return sites
