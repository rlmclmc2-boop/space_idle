def instrument_counters(project):
 A='preload("res://counter_probe.gd")'
 def edit(name,changes):
  p=project/'scripts'/name;s=p.read_text(encoding='utf8')
  for old,new in changes:
   assert s.count(old)==1,(name,old,s.count(old));s=s.replace(old,new,1)
  p.write_text(s,encoding='utf8')
 edit('game.gd',[
 ('func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:','func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:\n\t'+A+'.legacy_call("jewel_attack")'),
 ('func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:','func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:\n\t'+A+'.legacy_call("hit_enemy")'),
 ('\t\tcontext.snapshot.instance=new_attack_instance(context.snapshot)','\t\tif primary_missile:'+A+'.root(context.snapshot)\n\t\tcontext.snapshot.instance=new_attack_instance(context.snapshot)'),
 ('\tvar key:=str(enemy.uid)\n\tif not factors.has(key):','\tvar key:=str(enemy.uid)\n\tvar qa_cached=factors.has(key)\n\tif not factors.has(key):'),
 ('\tcontext.guidance_factors=factors\n\treturn N.multiply(raw,factors[key])','\tcontext.guidance_factors=factors\n\t'+A+'.guidance(enemy,context,qa_cached,layers)\n\treturn N.multiply(raw,factors[key])'),
 ('\tvar base_raw=raw\n\traw=guided_missile_damage(enemy,raw,context)','\t'+A+'.hit(enemy,context)\n\tvar base_raw=raw\n\traw=guided_missile_damage(enemy,raw,context)')])
 edit('presented_battle_game.gd',[('func tick_projectiles(dt:float)->void:','func tick_projectiles(dt:float)->void:\n\t'+A+'.legacy_call("tick_projectiles")')])
 edit('drone_combat_effects.gd',[('\t\tcontext.wild_used=true','\t\tcontext.wild_used=true\n\t\t'+A+'.blast()')])
