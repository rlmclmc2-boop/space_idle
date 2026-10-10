"""Limited inclusive timers in the runner-owned copy; never clean throughput."""
import re
from battle_phase_account import arguments

SCOPES={
 'main':['advance_game_time','refresh_visible_cards','refresh_navigation','refresh_draw_layers'],
 'battlefield':['before_logical_game_tick'],
 'game':['tick','jewel_fire','jewel_attack'],
 'presented_battle_game':['tick_projectiles'],
 'retained_enemy_contacts':['compile_record','paint'],
}

def prepare(project):
 scopes={k:list(v) for k,v in SCOPES.items()}
 scopes['main']+=['_ready','draw_battle']
 scopes['battlefield']+=['_ready']
 wrapped=[]
 for module,methods in scopes.items():
  path=project/'scripts'/(module+'.gd');source=path.read_text(encoding='utf-8')
  for name in methods:
   match=re.search(rf'^func {name}\((.*)\)([^\n]*):$',source,re.M)
   if not match:continue
   original='_spike_'+module+'_'+name
   call=original+'('+', '.join(arguments(match[1]))+')'
   indent=re.match(r'\n([ \t]+)',source[match.end():])[1]
   void=bool(re.search(r'->\s*void',match[2]))
   wrapper=match[0]+'\n'+indent+'var started=Time.get_ticks_usec()\n'
   wrapper+=indent+(call if void else 'var result='+call)+'\n'
   wrapper+=indent+f'if Engine.has_meta("saved_perf"):Engine.get_meta("saved_perf").record("{module}.{name}",Time.get_ticks_usec()-started)\n'
   if not void:wrapper+=indent+'return result\n'
   wrapper+='\n'+match[0].replace('func '+name+'(','func '+original+'(')
   source=source[:match.start()]+wrapper+source[match.end():];wrapped.append(module+'.'+name)
  path.write_text(source,encoding='utf-8')
 return wrapped
