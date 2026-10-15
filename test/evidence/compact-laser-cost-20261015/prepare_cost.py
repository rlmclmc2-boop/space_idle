from pathlib import Path
import hashlib, shutil

ROOT=Path(__file__).resolve().parents[3]
E=Path(__file__).resolve().parent
QA='const QACost=preload("res://qa_cost.gd")\n'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def exact(s,old,new,where):
 assert s.count(old)==1,(where,s.count(old))
 return s.replace(old,new,1)
def wrap(s,signature,key,args,returns=False):
 old_name=signature[5:signature.index('(')]
 alias=signature.replace('func '+old_name+'(','func _qa_'+key+'(',1)
 body=f'\tvar began=QACost.begin()\n\tvar result=_qa_{key}({args})\n\tQACost.finish("{key}",began)\n\treturn result\n' if returns else f'\tvar began=QACost.begin()\n\t_qa_{key}({args})\n\tQACost.finish("{key}",began)\n'
 return exact(s,signature,signature+body+alias,key)
def patch(project):
 result={}
 for name in ['battle_slice_runtime.gd','simulation_geometry_authority.gd','native_execution_session.gd','game.gd','presented_battle_game.gd','main.gd']:
  src=ROOT/'space-battleship/scripts'/name;dst=project/'scripts'/name
  assert sha(src)==sha(dst),name+' isolated source differs from branch'
  s=src.read_text(encoding='utf8')
  extends_line=next(line+'\n' for line in s.splitlines() if line.startswith('extends '))
  if name!='presented_battle_game.gd':
   s=exact(s,extends_line,extends_line+QA,name)
  if name=='battle_slice_runtime.gd':
   s=wrap(s,'func advance(seconds:float)->void:\n','slice_advance','seconds')
   s=wrap(s,'func snapshot()->void:\n','snapshot','')
  elif name=='simulation_geometry_authority.gd':
   s=wrap(s,'func before_tick(dt:float)->void:\n','geometry_before_tick','dt')
   s=wrap(s,'func after_tick()->void:\n','geometry_after_tick','')
  elif name=='native_execution_session.gd':
   s=wrap(s,'func advance(game:RefCounted,dt:float)->bool:\n','session_advance','game,dt',True)
   s=wrap(s,'func prepare_geometry(geometry:RefCounted,game:RefCounted)->void:\n','prepare_geometry','geometry,game')
   s=wrap(s,'func consume_feedback(game:RefCounted)->void:\n','consume_feedback','game')
   s=exact(s,'if not kernel.advance(dt):','var qa_kernel_started=QACost.begin()\n\tvar qa_kernel_ok=kernel.advance(dt)\n\tQACost.finish("kernel_advance_call",qa_kernel_started)\n\tif not qa_kernel_ok:',name)
  elif name=='game.gd':
   s=wrap(s,'func advance_shared_clock_and_economy(dt:float)->void:\n','shared_clock','dt')
  elif name=='presented_battle_game.gd':
   s=wrap(s,'func tick(dt:float)->void:\n','presented_tick','dt')
  elif name=='main.gd':
   s=wrap(s,'func draw_battle() -> void:\n','draw_battle','')
   s=wrap(s,'func draw_battle_foreground(flights: Variant, visible_projectiles: Array, offset: Vector2) -> void:\n','draw_battle_foreground','flights,visible_projectiles,offset')
   s=exact(s,'flights=game.combat_presentation.prepare_flights(self,visible_projectiles,offset)','var qa_prepare_started=QACost.begin()\n\t\tflights=game.combat_presentation.prepare_flights(self,visible_projectiles,offset)\n\t\tQACost.finish("presentation_prepare_flights",qa_prepare_started)',name)
   s=exact(s,'if game.combat_presentation!=null:game.combat_presentation.draw_flights(self,flights,offset)','if game.combat_presentation!=null:\n\t\tvar qa_draw_started=QACost.begin()\n\t\tgame.combat_presentation.draw_flights(self,flights,offset)\n\t\tQACost.finish("presentation_draw_flights",qa_draw_started)',name)
  dst.write_text(s,encoding='utf8');result[name]={'source_sha256':sha(src),'qa_sha256':sha(dst)}
 shutil.copy2(E/'qa_cost.gd',project/'qa_cost.gd')
 return result
def restore(project):
 for name in ['battle_slice_runtime.gd','simulation_geometry_authority.gd','native_execution_session.gd','game.gd','presented_battle_game.gd','main.gd']:
  shutil.copy2(ROOT/'space-battleship/scripts'/name,project/'scripts'/name)
