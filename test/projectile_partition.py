"""QA-only nonrecursive categorical partition inside the authority projectile loop."""
from pathlib import Path
import re
import shutil

def wrap(source, name, arguments, category):
    signature=next(line for line in source.splitlines() if line.startswith('func '+name+'('))
    original='_partition_original_'+name
    replacement=(signature+'\n\tvar timer=Engine.get_meta("projectile_partition")\n\tvar previous=timer.enter_phase('+str(category)+')\n\t'+original+'('+arguments+')\n\ttimer.leave_phase(previous)\n\n'+signature.replace(name,original,1))
    body=source[source.index(signature)+len(signature)+1:].splitlines()[0]
    if body.startswith(' ') and not body.startswith('\t'):replacement=replacement.replace('\t',' ')
    assert source.count(signature)==1
    return source.replace(signature,replacement,1)

def prepare(project: Path, root: Path, mode: str):
    shutil.copy2(root/'test/projectile_partition_timer.gd',project/'projectile_partition_timer.gd')
    sites=[]
    # Preserve exact synchronous signal arguments/order and every subscriber.
    for path in (project/'scripts').glob('*.gd'):
        source=path.read_text(encoding='utf-8')
        lines=[]
        for line in source.splitlines():
            if not line.lstrip().startswith('#'):
                line,n=re.subn(r'\b([A-Za-z_]\w*(?:\.\w+)*)\.event\.emit\(',r'Engine.get_meta("projectile_partition").emit_game(\1,',line)
                if path.name in ['game.gd','presented_battle_game.gd']:
                    line,m=re.subn(r'(?<![\w.])event\.emit\(',r'Engine.get_meta("projectile_partition").emit_game(self,',line);n+=m
                if n:sites.append([path.name,n])
            lines.append(line)
        path.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    path=project/'scripts/game.gd';source=path.read_text(encoding='utf-8')
    for name,args in [('hit_enemy','enemy,raw,type,effects,critical,context'),('hit_player','raw,type,context'),('apply_long_laser_hit','shot,due')]:source=wrap(source,name,args,1)
    signature=next(line for line in source.splitlines() if line.startswith('func tick_projectiles('))
    replacement=signature+'\n\tvar timer=Engine.get_meta("projectile_partition")\n\tvar ticket=timer.enter_loop(dt)\n\t_partition_original_tick_projectiles(dt)\n\ttimer.leave_loop(ticket)\n\n'+signature.replace('tick_projectiles','_partition_original_tick_projectiles',1)
    source=source.replace(signature,replacement,1)
    tail='\tprojectiles = projectiles.filter(func(p): return not p.dead and (not p.get("beam", false) or long_laser_valid(p)))'
    assert source.count(tail)==1
    source=source.replace(tail,'\tvar filter_previous=Engine.get_meta("projectile_partition").enter_phase(3)\n'+tail+'\n\tEngine.get_meta("projectile_partition").leave_phase(filter_previous)',1)
    path.write_text(source,encoding='utf-8')
    path=project/'combat_stress_fixture.gd';source=path.read_text(encoding='utf-8');source=wrap(source,'on_event','kind,info',4);path.write_text(source,encoding='utf-8')
    path=project/'probe.gd';source=path.read_text(encoding='utf-8')
    replacements=[
      (' Engine.set_meta("saved_perf",meter)',' Engine.set_meta("saved_perf",meter)\n var partition=preload("res://projectile_partition_timer.gd").new();partition.measure='+('true' if mode=='measure' else 'false')+'\n Engine.set_meta("projectile_partition",partition)'),
      ('  logical_ticks+=1','  logical_ticks+=1\n  Engine.get_meta("projectile_partition").begin_step()'),
      ('    sample_started=true;wall_start=','    Engine.get_meta("projectile_partition").begin_sample()\n    sample_started=true;wall_start='),
      ('  row.clock_validation={','  row.projectile_partition=Engine.get_meta("projectile_partition").report(self,tick_count)\n  row.clock_validation={'),
      (' Engine.remove_meta("saved_perf")',' Engine.remove_meta("saved_perf")\n Engine.remove_meta("projectile_partition")')]
    for old,new in replacements:
        assert source.count(old)==1,old
        source=source.replace(old,new,1)
    path.write_text(source,encoding='utf-8')
    return sites
