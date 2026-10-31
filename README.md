# Four-node simulated phase segment: fixed local evidence

Source `feat/planet-single-side-ui@8eb53970`, Godot 4.7.2, 2048×768, OpenGL 4.5 Mesa llvmpipe. The script sets all four built, then calls `visual.advance(0.25, false)` between frames 000–024. The 25 PNGs represent simulation sample times 0 through 6.0 seconds. The MP4 encodes them at 4 fps for a 6.25-second playback; `ffprobe.json` records the stream properties. The ALSA warning in the capture log is absent host audio hardware.

Representative frames 000/006/012/018/024 were inspected at original size. Their visible ring and four nodes stay connected and depth masking remains stable. This is a bounded simulated-step segment: it does not demonstrate natural wall-clock motion, natural construction progress, a full orbit or overall visual approval.
