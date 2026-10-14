from pathlib import Path
import shutil
r=Path('D:/CodexBuild/space_idle/stable-integration');work=r/'test/work';iso=work/'battle-fix-20261013/space-battleship';src=r/'test/evidence/presentation-strip-20261014'
s=(src/'qa_strip_current.gd').read_text(encoding='utf-8')
s=s.replace('func run()->void:', '''func cpu_handshake(label:String,phase:String)->int:
 var began:=Time.get_ticks_usec()
 print("CPU_MARK ",label," ",phase)
 var path:="res://.runtime/cpu-ack-"+label+"-"+phase
 while not FileAccess.file_exists(path):
  assert(Time.get_ticks_usec()-began<5000000,"CPU sampler did not acknowledge")
  OS.delay_msec(1)
 return Time.get_ticks_usec()-began
func run()->void:''')
s=s.replace(' Gate.steps=0;Gate.limit=180;', ''' Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 OS.low_processor_usage_mode=false
 assert(Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0)
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED)
 Gate.steps=0;Gate.limit=180;''')
s=s.replace(' var begin:=Time.get_ticks_usec();var previous:=begin',' var cpu_begin_wait:=cpu_handshake(label,"begin")\n var sampling_us:=0\n var begin:=Time.get_ticks_usec();var previous:=begin')
s=s.replace('  var now:=Time.get_ticks_usec();frames.append(now-previous)','  var now:=Time.get_ticks_usec();var sample_start:=now;frames.append(now-previous)\n  assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"limiter restored")')
s=s.replace('  previous=now\n scene.set_process(false);Gate.sampled=false','  previous=now\n  sampling_us+=Time.get_ticks_usec()-sample_start\n scene.set_process(false);Gate.sampled=false\n var cpu_end_wait:=cpu_handshake(label,"end")')
s=s.replace(' var row={"label":label,',' var row={"uncapped":true,"sampling_us":sampling_us,"cpu_begin_handshake_us":cpu_begin_wait,"cpu_end_handshake_us":cpu_end_wait,"low_processor_mode":OS.low_processor_usage_mode,"physics_ticks_per_second":Engine.physics_ticks_per_second,"label":label,')
(iso/'qa_strip_uncapped.gd').write_text(s,encoding='utf-8')
shutil.copy2(src/'prepare_strip.py',work/'prepare_strip.py')
print('Prepared uncapped driver; production settings untouched')
