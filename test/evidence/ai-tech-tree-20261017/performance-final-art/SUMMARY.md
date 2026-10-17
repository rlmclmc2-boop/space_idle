# AI tech tree final art: five high load cases

Absent = baseline without the tree; Closed = integrated tree with equipment tab visible; Open = integrated tree with technology tab and final static art visible. Every case ran in A-B-C-D-E order (Absent, Closed, Open, Closed, Absent). The art was enabled in both integrated states.

Godot 4.7.2, RTX 2060, OpenGL Compatibility, 1373x883, 1x/60 Hz, FPS cap 0, VSync off, cache on, save off. Each run used 240 warmup and 480 sampled logic steps with 15 live enemies. All 25 runs passed native admission, sample validity, 1x rate, frame phase closure, and identical combat event/stress counts within each case.

Times below are milliseconds. Main process is wall time for `main/battlefield._process`, including game tick and UI; it is not isolated `BattleGame.tick` CPU time. Bracketed states are averaged. Their repeat span estimates run drift. Open differs in visible page, so its lower frame times cannot be attributed to a faster technology system.

| Case | Absent frame mean/P95 | Closed frame mean/P95 | Open frame mean/P95 | Closed - absent | Open - closed | Repeat span absent/closed | Main process mean absent/closed/open |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| mixed | 7.482/10.943 | 7.922/11.931 | 6.702/9.478 | +0.440 (+5.9%) | -1.220 (-15.4%) | 0.097/0.596 | 2.705/2.895/2.323 |
| laser | 5.473/8.691 | 5.526/8.729 | 4.902/7.840 | +0.054 (+1.0%) | -0.625 (-11.3%) | 0.002/0.015 | 2.221/2.224/1.981 |
| cannon | 7.561/11.915 | 7.512/11.212 | 6.809/10.109 | -0.049 (-0.6%) | -0.703 (-9.4%) | 0.342/0.255 | 2.218/2.167/1.907 |
| missile | 7.012/9.874 | 7.096/10.015 | 6.310/8.737 | +0.084 (+1.2%) | -0.786 (-11.1%) | 0.144/0.025 | 2.292/2.301/2.004 |
| longLaser | 8.627/13.200 | 8.610/13.102 | 8.180/12.711 | -0.018 (-0.2%) | -0.429 (-5.0%) | 0.100/0.253 | 2.815/2.780/2.615 |

Raw 25 JSON traces and system load samples are stored as `.json.gz`; original logs, five open state PNGs, and mixed absent/closed PNGs are alongside them. See `summary.json` for every run and executable hashes. Run `report.py` from the original `test/work/ai-tech-perf-20261017` workspace to regenerate the package.
