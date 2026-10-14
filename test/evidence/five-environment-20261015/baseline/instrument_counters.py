def instrument_counters(project):
 A='preload("res://counter_probe.gd")'
 for filename,functions in {'game.gd':['jewel_attack','hit_enemy'],'presented_battle_game.gd':['tick_projectiles']}.items():
  p=project/'scripts'/filename;lines=p.read_text(encoding='utf8').splitlines(True);out=[]
  for line in lines:
   out.append(line)
   for name in functions:
    if line.startswith('func '+name+'('):out.append('\t'+A+'.legacy_call("'+name+'")\n')
  p.write_text(''.join(out),encoding='utf8')
