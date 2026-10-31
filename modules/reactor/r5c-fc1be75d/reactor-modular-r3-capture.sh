#!/usr/bin/env bash
set -euo pipefail
cd /workspace/space_idle/space-battleship
export DISPLAY=:99
export XDG_DATA_HOME=/tmp/reactor-modular-xdg/data
export XDG_CONFIG_HOME=/tmp/reactor-modular-xdg/config
export XDG_CACHE_HOME=/tmp/reactor-modular-xdg/cache
export SPACE_IDLE_NATIVE_EXTENSION=/tmp/space-idle-native472/bin/libspace_native.so
rm -f /tmp/reactor-modular-video-ready
/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64 --path . --rendering-driver opengl3 --audio-driver Dummy --script /tmp/reactor-modular-video-driver20.gd > /tmp/reactor-modular-r3-video-runtime.log 2>&1 &
godot_pid=$!
for i in {1..90}; do
  if [[ -s /tmp/reactor-modular-video-ready ]]; then break; fi
  if ! kill -0 "$godot_pid" 2>/dev/null; then break; fi
  sleep .5
done
if [[ ! -s /tmp/reactor-modular-video-ready ]]; then
  wait "$godot_pid" || true
  echo "No video-ready marker" >&2
  exit 1
fi
window_id=$(xwininfo -root -tree | sed -n '/太空战舰 (DEBUG)/s/^ *\(0x[0-9a-f]*\).*/\1/p' | head -1)
if [[ -z "$window_id" ]]; then
  echo "No Godot window" >&2
  exit 1
fi
ffmpeg -hide_banner -loglevel info -f x11grab -framerate 25 -video_size 1440x900 -window_id "$window_id" -i :99 -t 10 -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p -y /tmp/reactor-modular-r3-10s-1440x900-25fps.mp4 > /tmp/reactor-modular-r3-ffmpeg.log 2>&1
wait "$godot_pid"
printf 'WINDOW=%s\n' "$window_id"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames,r_frame_rate -show_entries format=duration -of default=nw=1 /tmp/reactor-modular-r3-10s-1440x900-25fps.mp4
