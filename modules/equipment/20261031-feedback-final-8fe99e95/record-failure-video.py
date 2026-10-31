import subprocess,os,time,json
from pathlib import Path
out=Path('/tmp/space-idle-workbench-rebuild/failure-feedback')
env=os.environ.copy();env.update(DISPLAY=':99',XDG_DATA_HOME='/tmp/space-idle-godot-data',XDG_CACHE_HOME='/tmp/space-idle-godot-cache',SPACE_IDLE_SETTINGS_PATH='/tmp/space-idle-workbench-rebuild/focused-settings.json',SPACE_IDLE_NATIVE_EXTENSION='/tmp/space-idle-native472/space_native.gdextension')
with (out/'recording.log').open('w') as video_log, (out/'video-runtime.log').open('w') as runtime_log:
 camera=subprocess.Popen(['ffmpeg','-y','-f','x11grab','-framerate','15','-video_size','1440x900','-i',':99.0+0,0','-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p',str(out/'operations-raw.mp4')],stdin=subprocess.PIPE,stdout=video_log,stderr=video_log,env=env)
 started=time.monotonic()
 result=subprocess.run(['/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64','--path','space-battleship','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','/tmp/space-idle-workbench-rebuild/failure-video.gd'],cwd='/workspace/space_idle',env=env,stdout=runtime_log,stderr=subprocess.STDOUT)
 camera.communicate(b'q\n',timeout=30)
 (out/'video-run.json').write_text(json.dumps({'godot_exit':result.returncode,'ffmpeg_exit':camera.returncode,'seconds':time.monotonic()-started,'note':'Actual X11 capture; no performance results drawn from recorded run'},indent=2))
 print('VIDEO_RUN',result.returncode,camera.returncode,flush=True)
