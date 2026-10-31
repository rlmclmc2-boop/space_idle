from pathlib import Path
import subprocess
import time

marker=Path('/tmp/reactor-r11-evidence/reactor-r11v-final-video-ready')
deadline=time.monotonic()+30
while not marker.exists():
    if time.monotonic()>=deadline:
        raise SystemExit('Godot preview did not reach video marker')
    time.sleep(.05)
subprocess.run([
    'ffmpeg','-hide_banner','-loglevel','warning','-y',
    '-f','x11grab','-framerate','30','-video_size','1440x900',
    '-i',':100.0+0,0','-frames:v','250','-vf','format=yuv420p',
    '-c:v','libx264','-preset','ultrafast','-crf','16',
    '-movflags','+faststart','/tmp/reactor-r11-evidence/reactor-r11v-final-1x-250frames.mp4',
],check=True)
