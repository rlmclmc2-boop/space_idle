from pathlib import Path

def instrument_missile(project):
 def edit(name,changes):
  p=project/'scripts'/name;s=p.read_text(encoding='utf8')
  for old,new in changes:
   assert s.count(old)==1,(name,old,s.count(old))
   s=s.replace(old,new,1)
  p.write_text(s,encoding='utf8')
 A='preload("res://missile_audit.gd")'
 edit('game.gd',[
  ('func tick(dt: float) -> void:', 'func tick(dt: float) -> void:\n\t'+A+'.tick()'),
  ('func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:', 'func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:\n\t'+A+'.legacy_call("jewel_attack")'),
  ('\t\tcontext.snapshot.instance=new_attack_instance(context.snapshot)', '\t\tif primary_missile:'+A+'.legacy_root(self,context.snapshot)\n\t\tcontext.snapshot.instance=new_attack_instance(context.snapshot)'),
  ('\tvar key:=str(enemy.uid)\n\tif not factors.has(key):','\tvar key:=str(enemy.uid)\n\tvar qa_cached=factors.has(key)\n\tif not factors.has(key):'),
  ('\tcontext.guidance_factors=factors\n\treturn N.multiply(raw,factors[key])','\tcontext.guidance_factors=factors\n\t'+A+'.legacy_guidance(enemy,context,qa_cached,layers)\n\treturn N.multiply(raw,factors[key])'),
  ('\tvar base_raw=raw\n\traw=guided_missile_damage(enemy,raw,context)','\t'+A+'.legacy_call("hit_enemy")\n\t'+A+'.legacy_hit(enemy,raw,context)\n\tvar base_raw=raw\n\traw=guided_missile_damage(enemy,raw,context)'),
  ('\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\tcontinue','\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\t'+A+'.cancelled(self,pending,entry)\n\t\t\tcontinue')])
 edit('presented_battle_game.gd', [('\t\t\tcancelled_ejections+=1;continue','\t\t\t'+A+'.cancelled_packet(self,packet)\n\t\t\tcancelled_ejections+=1;continue')])
 edit('drone_combat_effects.gd', [('\t\tcontext.wild_used=true','\t\tcontext.wild_used=true\n\t\t'+A+'.legacy_blast()')])
 edit('native_execution_session.gd',[
  ('\tif not kernel.advance(dt):','\t'+A+'.before_native(game,kernel)\n\tif not kernel.advance(dt):'),
  ('\tgame.native_step_phase="native_done"','\t'+A+'.after_native(kernel)\n\tgame.native_step_phase="native_done"'),
  ('\tfor row in kernel.take_feedback():','\tfor row in kernel.take_feedback():\n\t\t'+A+'.native_row(row)'),
  ('\tconsume_feedback(game)\n\tif handed_off:', '\tconsume_feedback(game)\n\t'+A+'.end_native()\n\tif handed_off:')])

