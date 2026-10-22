from pathlib import Path
import ctypes,ctypes.wintypes as w,hashlib,json,os,shutil,subprocess,time,sys,tarfile,io
root=Path(__file__).resolve().parent
project=root/'game-project'
frozen=json.loads((root/'evidence/cold-1792651156512517400/freeze.json').read_text())
if '--runtime-ref' in sys.argv:
    ref=sys.argv[sys.argv.index('--runtime-ref')+1]
    repo=root.parent/'p2-runtime'
    archive=subprocess.check_output(['git','archive',ref,'space-battleship/scripts'],cwd=repo)
    hashes={}
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        for entry in bundle.getmembers():
            if not entry.isfile():continue
            destination=project/Path(entry.name).relative_to('space-battleship')
            assert destination.resolve().is_relative_to(project.resolve())
            data=bundle.extractfile(entry).read()
            destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data)
            hashes[entry.name]=hashlib.sha256(data).hexdigest()
    frozen={'runtime_sha':ref,'source_sha256':hashes}
for path,digest in frozen['source_sha256'].items():
    assert hashlib.sha256((project/Path(path).relative_to('space-battleship')).read_bytes()).hexdigest()==digest,path
probe=(root/'workload_probe.gd').read_bytes()
(project/'workload_probe.gd').write_bytes(probe)
originals={};overlays={}
if '--trace-main' in sys.argv:
    for name,calls in {'main.gd':['game.process_equipment_queries()','advance_unlock_notice()','game.check_timed_save()','sync_accelerated_visual_mode()','prune_resource_samples(Time.get_unix_time_from_system())','refresh_visible_cards(dt)','refresh_navigation()','refresh_draw_layers(dt)'],'battlefield.gd':['_process_battlefield(delta)','super._process(delta)','_battlefield_motion_frame(delta)']}.items():
        path=project/'scripts'/name
        originals[path]=path.read_bytes()
        source=originals[path].decode('utf-8')
        for call in calls:
            needle='\n\t'+call+'\n'
            if needle not in source:raise RuntimeError('missing trace site '+call)
            source=source.replace(needle,'\n\tprint("P2_MAIN ",Time.get_ticks_usec()," begin '+call+'")'+needle+'\tprint("P2_MAIN ",Time.get_ticks_usec()," end '+call+'")\n')
        path.write_bytes(source.encode('utf-8'))
        overlays[name]=hashlib.sha256(path.read_bytes()).hexdigest()
if '--trace-save' in sys.argv:
    patches={
      'game.gd':[
        ('\tvar saved := _build_save_data()','\tprint("P2_SAVE ",Time.get_ticks_usec()," build begin")\n\tvar saved := _build_save_data()\n\tprint("P2_SAVE ",Time.get_ticks_usec()," build end")'),
        ('\tlast_save_error = progress_writer.write_progress(JSON.stringify(saved, "\\t").to_utf8_buffer())','\tvar p2_bytes:=JSON.stringify(saved, "\\t").to_utf8_buffer()\n\tprint("P2_SAVE ",Time.get_ticks_usec()," encode end")\n\tlast_save_error = progress_writer.write_progress(p2_bytes)\n\tprint("P2_SAVE ",Time.get_ticks_usec()," writer end")')],
      'save_transfer.gd':[
        (' if not shape(raw,schema()):return {"error":"format"}',' print("P2_SAVE ",Time.get_ticks_usec()," shape begin")\n if not shape(raw,schema()):return {"error":"format"}\n print("P2_SAVE ",Time.get_ticks_usec()," shape end")'),
        (' var candidate:=BattleGame.new(db,false)',' print("P2_SAVE ",Time.get_ticks_usec()," candidate begin")\n var candidate:=BattleGame.new(db,false)\n print("P2_SAVE ",Time.get_ticks_usec()," candidate constructed")'),
        (' candidate.load_progress_data(clean(raw,schema()))',' candidate.load_progress_data(clean(raw,schema()))\n print("P2_SAVE ",Time.get_ticks_usec()," candidate loaded")'),
        (' candidate.reset_player()',' candidate.reset_player()\n print("P2_SAVE ",Time.get_ticks_usec()," candidate reset")')],
      'progress_writer.gd':[
        ('\tvar decoded = preload("res://scripts/currency_storage.gd").parse_source(source)','\tprint("P2_SAVE ",Time.get_ticks_usec()," tokens begin")\n\tvar decoded = preload("res://scripts/currency_storage.gd").parse_source(source)\n\tprint("P2_SAVE ",Time.get_ticks_usec()," tokens end")'),
        ('\treturn load("res://scripts/save_transfer.gd").new().prepare_disk_data(data, database)','\tprint("P2_SAVE ",Time.get_ticks_usec()," semantic begin")\n\tvar p2_checked:Dictionary=load("res://scripts/save_transfer.gd").new().prepare_disk_data(data, database)\n\tprint("P2_SAVE ",Time.get_ticks_usec()," semantic end")\n\treturn p2_checked')]
    }
    for name,replacements in patches.items():
        path=project/'scripts'/name;originals[path]=path.read_bytes()
        source=originals[path].decode('utf-8')
        for before,after in replacements:
            assert before in source,(name,before)
            source=source.replace(before,after)
        path.write_bytes(source.encode('utf-8'));overlays[name]=hashlib.sha256(path.read_bytes()).hexdigest()
run=root/'evidence'/('workload-'+str(time.time_ns()));run.mkdir()
env=os.environ.copy()
for key,name in (('APPDATA','Roaming'),('LOCALAPPDATA','Local')):
    env[key]=str(run/name);Path(env[key]).mkdir()
engine=r'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64.exe'
cmd=[engine,'--headless','--audio-driver','Dummy','--path',str(project),'--script','workload_probe.gd','--','--capture']
freeze={'runtime_sha':frozen['runtime_sha'],'source_sha256':frozen['source_sha256'],'engine_sha256':hashlib.sha256(Path(engine).read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(probe).hexdigest(),'frames':600,'frame_rate':60,'resource':{'m':1,'e':3800},'material':1000,'schedule':'one source credit and actual research call/frame; drop source each30 frames; frozen galaxy source each60; real save each120. Actual main UI process, combat paused; controlled source fixtures, not full battle benchmark.','command':cmd,'appdata':env['APPDATA'],'localappdata':env['LOCALAPPDATA']}
freeze['diagnostic_print_overlays']=overlays
(run/'freeze.json').write_text(json.dumps(freeze,indent=2),encoding='utf-8')
class Memory(ctypes.Structure):
    _fields_=[('cb',w.DWORD),('PageFaultCount',w.DWORD)]+[(k,ctypes.c_size_t) for k in ('PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage')]
getmem=ctypes.WinDLL('psapi').GetProcessMemoryInfo
getmem.argtypes=[w.HANDLE,ctypes.POINTER(Memory),w.DWORD];getmem.restype=w.BOOL
output_file=(run/'stdout.log').open('wb');error_file=(run/'stderr.log').open('wb')
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
proc=subprocess.Popen(cmd,env=env,stdout=output_file,stderr=error_file,startupinfo=startup)
peak=0;memory_ok=True;start=time.monotonic()
while proc.poll() is None and time.monotonic()-start<45:
    mem=Memory();mem.cb=ctypes.sizeof(mem)
    if getmem(w.HANDLE(int(proc._handle)),ctypes.byref(mem),mem.cb):peak=max(peak,mem.PeakWorkingSetSize)
    else:memory_ok=False
    time.sleep(.05)
timed_out=proc.poll() is None
if timed_out:proc.kill()
proc.wait();output_file.close();error_file.close()
for path,data in originals.items():path.write_bytes(data)
out=(run/'stdout.log').read_bytes();err=(run/'stderr.log').read_bytes()
rows=[json.loads(line[len(b'P2_WORKLOAD_RESULT '):]) for line in out.splitlines() if line.startswith(b'P2_WORKLOAD_RESULT ')]
passed=proc.returncode==0 and b'P2_WORKLOAD_COMPLETE' in out and len(rows)==1 and rows[0]['status']=='PASS' and not any(s in out+err for s in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:',b'P2_FAIL'))
receipt={'status':'PASS' if passed else 'FAIL','exit_code':proc.returncode,'timed_out':timed_out,'seconds':time.monotonic()-start,'measurement':rows,'own_child_peak_rss_bytes':peak,'memory_sampling_ok':memory_ok,'stdout_sha256':hashlib.sha256(out).hexdigest(),'stderr_sha256':hashlib.sha256(err).hexdigest()}
(run/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({'evidence':str(run),**receipt}));print(err.decode('utf-8',errors='replace')[-5000:])
raise SystemExit(0 if passed else 1)
