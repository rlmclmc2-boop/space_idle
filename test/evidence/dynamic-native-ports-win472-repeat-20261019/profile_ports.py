"""QA-only RAM timers. Applied only to isolated scripts, never shipping sources.

Wrappers call each original function exactly once with unchanged arguments/return.
Candidate-only timers surround the existing new port-array generation and native
input. Driver edit is one cold export after the sample. No projectile, ray,
visual, save, numeric or kernel code is replaced.
"""
def once(text,old,new):
    if text.count(old)!=1:raise RuntimeError('Unexpected source anchor count: '+old[:90])
    return text.replace(old,new,1)

def instrument_session(text,label):
    names=['prepare_total','advance_total','kernel_advance','feedback_total',
           'ports_total','ports_compute','ports_native_input']
    declaration='const QA_PORTS_PROBE=preload("res://probe.gd")\nvar qa_profile:Dictionary={\n'
    declaration+=',\n'.join('\t"'+n+'":{"calls":0,"us":0,"max_us":0}' for n in names)+'\n}\n'
    text=once(text,'extends RefCounted\n','extends RefCounted\n'+declaration)
    if label=='after':
        start=text.index('\tif kernel.has_method("input_presentation_muzzles"):\n')
        end=text.index('\tvar topology_changed:',start)
        block=text[start:end]
        block=once(block,'\t\tvar ports:Array=[]\n','\t\tvar ports:Array=[]\n\t\tvar _qa_build_start:int=Time.get_ticks_usec() if _qa_ports_active else 0\n')
        block=once(block,'\t\tif ports!=presentation_muzzles:\n','\t\tif _qa_ports_active:_qa_profile_add("ports_compute",Time.get_ticks_usec()-_qa_build_start)\n\t\tif ports!=presentation_muzzles:\n')
        old='\t\t\tvar accepted:bool=kernel.input_presentation_muzzles(ports)\n'
        new='\t\t\tvar _qa_input_start:int=Time.get_ticks_usec() if _qa_ports_active else 0\n'+old+'\t\t\tif _qa_ports_active:_qa_profile_add("ports_native_input",Time.get_ticks_usec()-_qa_input_start)\n'
        block=once(block,old,new)
        block='\tvar _qa_ports_active:bool=QA_PORTS_PROBE.active\n\tvar _qa_ports_start:int=Time.get_ticks_usec() if _qa_ports_active else 0\n'+block+'\tif _qa_ports_active:_qa_profile_add("ports_total",Time.get_ticks_usec()-_qa_ports_start)\n'
        text=text[:start]+block+text[end:]
    old='\tif not kernel.advance(dt):\n'
    new='\tvar _qa_kernel_active:bool=QA_PORTS_PROBE.active\n\tvar _qa_kernel_start:int=Time.get_ticks_usec() if _qa_kernel_active else 0\n\tvar _qa_kernel_ok:bool=kernel.advance(dt)\n\tif _qa_kernel_active:_qa_profile_add("kernel_advance",Time.get_ticks_usec()-_qa_kernel_start)\n\tif not _qa_kernel_ok:\n'
    text=once(text,old,new)
    signatures=[('prepare_geometry','geometry:RefCounted,game:RefCounted','geometry,game','void','prepare_total'),
                ('advance','game:RefCounted,dt:float','game,dt','bool','advance_total'),
                ('consume_feedback','game:RefCounted','game','void','feedback_total')]
    wrappers=[]
    for name,args,call,ret,metric in signatures:
        text=once(text,'func '+name+'('+args+')->'+ret+':','func _qa_original_'+name+'('+args+')->'+ret+':')
        original='_qa_original_'+name+'('+call+')'
        if ret=='void':
            body='\tif not QA_PORTS_PROBE.active:\n\t\t'+original+'\n\t\treturn\n\tvar start:int=Time.get_ticks_usec()\n\t'+original+'\n\t_qa_profile_add("'+metric+'",Time.get_ticks_usec()-start)\n'
        else:
            body='\tif not QA_PORTS_PROBE.active:return '+original+'\n\tvar start:int=Time.get_ticks_usec()\n\tvar result:bool='+original+'\n\t_qa_profile_add("'+metric+'",Time.get_ticks_usec()-start)\n\treturn result\n'
        wrappers.append('func '+name+'('+args+')->'+ret+':\n'+body)
    text+='\nfunc _qa_profile_add(name:String,elapsed:int)->void:\n\tvar row:Dictionary=qa_profile[name]\n\trow.calls+=1;row.us+=elapsed;row.max_us=maxi(int(row.max_us),elapsed)\n\n'+'\n'.join(wrappers)
    return text

def instrument_driver(text):
    return once(text,'row.runtime_config_end=config(scene)',
        'row.qa_profile=g.native_execution.qa_profile.duplicate(true)\n row.qa_weapon_rows=g.native_execution.weapons.size()\n row.qa_profile_scope="QA RAM timers only while Probe.active; nested inclusive spans; not acceptance performance"\n row.runtime_config_end=config(scene)')
