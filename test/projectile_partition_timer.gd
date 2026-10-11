extends RefCounted
# QA-only categorical switches, no per-callee tree or recursive self profiler.
# Categories are mutually exclusive within the base loop; signal dispatch may
# contain authority callbacks, so listeners is not synonymous with pure visuals.
var enabled=false
var measure=true
var active=false
var phase=0
var stamp=0
var root_stamp=0
var nesting=0
var current={}
var rows=[]
var outside=0
func begin_sample()->void:
 enabled=true;rows.clear();current={};outside=0
func begin_step()->void:
 if not enabled:return
 if not current.is_empty():rows.append(current)
 current={"us":[0,0,0,0,0],"total_us":0,"loop_calls":0,"dt":0.,"switch_calls":0,"signal_calls":0,"projection_us":[0,0,0,0,0],"projection_calls":[0,0,0,0,0]}
func enter_loop(dt:float)->int:
 if not enabled:return 0
 if current.is_empty():outside+=1;return 0
 if active:nesting+=1;return 2
 active=true;phase=0;nesting=1
 root_stamp=Time.get_ticks_usec();stamp=root_stamp
 current.loop_calls+=1;current.dt+=dt
 return 1
func leave_loop(ticket:int)->void:
 if ticket==0:return
 nesting-=1
 if ticket==2:return
 var now=Time.get_ticks_usec()
 if measure:current.us[phase]+=now-stamp
 current.total_us+=now-root_stamp
 active=false
func enter_phase(next:int)->int:
 if not active:return -1
 var previous=phase
 current.switch_calls+=1
 if next!=phase:
  if measure:
   var now=Time.get_ticks_usec();current.us[phase]+=now-stamp;stamp=now
  phase=next
 return previous
func leave_phase(previous:int)->void:
 if previous<0 or previous==phase:return
 if measure:
  var now=Time.get_ticks_usec();current.us[phase]+=now-stamp;stamp=now
 phase=previous
func begin_projection()->int:
 if not active:return -1
 current.projection_calls[phase]+=1
 if not measure:return -1
 return (Time.get_ticks_usec()<<3)|phase
func end_projection(token:int)->void:
 if token<0:return
 var elapsed=Time.get_ticks_usec()-(token>>3)
 current.projection_us[token&7]+=elapsed
func emit_game(game,kind,payload)->void:
 if active:current.signal_calls+=1
 var previous=enter_phase(2)
 game.event.emit(kind,payload)
 leave_phase(previous)
func report(tree:SceneTree,steps:int)->Dictionary:
 enabled=false
 if not current.is_empty():rows.append(current);current={}
 var categories={};var names=["kernel_and_scheduling","authority_hit_exclusive","signal_listeners_exclusive","tail_filter_exclusive","qa_observer_exclusive"]
 for i in names.size():
  var values=[]
  for row in rows:values.append(row.us[i])
  categories[names[i]]=tree.stats(values)
 var projection={};var projection_calls={}
 for i in names.size():
  var values=[];var calls=0
  for row in rows:values.append(row.projection_us[i]);calls+=row.projection_calls[i]
  projection[names[i]]=tree.stats(values);projection_calls[names[i]]=calls
 var totals=[];var dt=0.;var loops=0;var signals=0;var switches=0;var mismatch=0
 for row in rows:
  totals.append(row.total_us);dt+=row.dt;loops+=row.loop_calls;signals+=row.signal_calls;switches+=row.switch_calls
  if measure and row.us.reduce(func(a,b):return a+b,0)!=row.total_us:mismatch+=1
 return {"mode":"measure" if measure else "empty","logical_steps":steps,"measured_steps":rows.size(),"step_count_equal":steps==rows.size(),"outside_step_calls":outside,"unclosed_loop":active or nesting!=0,"category_sum_mismatch_steps":mismatch,"loop_calls":loops,"dt_seconds":dt,"signal_calls":signals,"switch_calls":switches,"total_us_per_step":tree.stats(totals),"exclusive_us_per_step":categories,"projection_us_per_step_by_parent":projection,"projection_calls_by_parent":projection_calls,"rows":rows,"scope":"Base tick_projectiles only; presented ejection preparation is outside. Kernel residual includes snapshot, scheduling, validity, target projection and motion/collision, not pure physics. Hit/apply_long_laser_hit authority excludes timed signal dispatch; listeners includes all synchronous production callbacks, excluding QA stress observer. Same-category nested hits do not double count. Projection sub-timer overlaps its parent category and must not be added; only target_point provider path timed. Categories sum to total; timer overhead remains in them. Empty executes identical wrappers/switch bookkeeping with only outer-loop clocks."}
