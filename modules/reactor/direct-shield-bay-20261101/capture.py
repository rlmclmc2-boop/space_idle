from pathlib import Path
import os,subprocess,time
p=Path(__file__).resolve().parent
env=os.environ.copy();env.update(DISPLAY=":100",XDG_DATA_HOME="/tmp/reactor-final-runtime/data",XDG_CONFIG_HOME="/tmp/reactor-final-runtime/config",XDG_CACHE_HOME="/tmp/reactor-final-runtime/cache")
binary="/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64"
with (p/"import.log").open("w") as f:
 subprocess.run([binary,"--headless","--path",".","--editor","--import"],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
marker=p/"reactor-direct-video-ready";marker.unlink(missing_ok=True)
with (p/"game.log").open("w") as log:
 game=subprocess.Popen([binary,"--path",".","--rendering-method","gl_compatibility","--script",str(p/"preview.gd")],env=env,stdout=log,stderr=subprocess.STDOUT)
 try:
  deadline=time.monotonic()+60
  while not marker.exists():
   if game.poll() is not None:raise RuntimeError("game exited before ready")
   if time.monotonic()>deadline:raise RuntimeError("ready timeout")
   time.sleep(.05)
  subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-f","x11grab","-framerate","25","-video_size","1440x900","-i",":100.0+0,0","-frames:v","250","-c:v","libx264","-preset","ultrafast","-crf","16","-pix_fmt","yuv420p",str(p/"flow-10s.mp4")],check=True)
  game.wait(timeout=30)
  print("captured; game exit",game.returncode)
 finally:
  if game.poll() is None:game.terminate();game.wait()
