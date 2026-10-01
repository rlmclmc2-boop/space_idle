from pathlib import Path
import re,sys,shutil
p=Path(sys.argv[1]);source=p/'scripts/battlefield.gd';s=source.read_text()
assert "func _fx_original_draw_projectile_fx(" not in s, "Project is already instrumented"
pattern=r'^func draw_projectile_fx\((.*)\)(.*):$';m=re.search(pattern,s,re.M);assert m
args=[v.strip().split(':')[0].split('=')[0].strip() for v in m[1].split(',') if v.strip()]
call='_fx_original_draw_projectile_fx('+','.join(args)+')'
wrapper=m[0]+'''
\tvar _diag=Engine.get_meta("fx_tail",null)
\tif _diag==null or not _diag.enabled:return CALL
\tvar _started:=Time.get_ticks_usec()
\tvar _cpu:int=_diag.cpu_now()
\tvar _value=CALL
\tvar _cpu_end:int=_diag.cpu_now()
\tvar _elapsed:=Time.get_ticks_usec()-_started
\t_diag.record("fx.call",_elapsed,_cpu_end-_cpu if _cpu>=0 else -1,shot,core,visual)
\treturn _value

'''.replace('CALL',call)+m[0].replace('func draw_projectile_fx(','func _fx_original_draw_projectile_fx(')
s=s[:m.start()]+wrapper+s[m.end():];source.write_text(s)
source=p/'dev/toon_ship/missile_vfx.gd';s=source.read_text()
s=s.replace('\tvar ribbon:=PackedVector2Array()', '''\tvar _diag=Engine.get_meta("fx_tail",null)
\tvar _measure:bool=_diag!=null and _diag.enabled
\tvar _geometry_started:=Time.get_ticks_usec() if _measure else 0
\tvar _geometry_cpu:int=_diag.cpu_now() if _measure else -1
\tvar ribbon:=PackedVector2Array()''')
old='\tif ribbon.size()>1:surface.draw_polyline(ribbon,Color(AMBER,0.22+clampf(budget,0.0,1.0)*0.16),1.4,true)'
new='''\tif _measure:
\t\tvar _cpu_end:int=_diag.cpu_now()
\t\t_diag.record("trail.geometry",Time.get_ticks_usec()-_geometry_started,_cpu_end-_geometry_cpu if _geometry_cpu>=0 else -1,visual.get("shot",{}),core,visual,ribbon)
\tvar _submit_started:=Time.get_ticks_usec() if _measure else 0
\tvar _submit_cpu:int=_diag.cpu_now() if _measure else -1
'''+old+'''
\tif _measure:
\t\tvar _cpu_end:int=_diag.cpu_now()
\t\t_diag.record("trail.submit",Time.get_ticks_usec()-_submit_started,_cpu_end-_submit_cpu if _submit_cpu>=0 else -1,visual.get("shot",{}),core,visual,ribbon)'''
assert old in s;s=s.replace(old,new);source.write_text(s)
shutil.copy2(Path(__file__).with_name('fx_tail_meter.gd'),p/'fx_tail_meter.gd')
