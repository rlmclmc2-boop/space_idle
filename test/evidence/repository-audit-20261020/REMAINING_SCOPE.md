# Remaining test audit scope

`test-status-current.csv` lists every tracked top-level `test_*.gd` and `test_*.py` file and separates current receipts from the initial scan. After retiring `test_crew_scientists.gd` and moving the import recovery worker under `test/fixtures/`, it contains 344 files. Sixteen have direct continuation receipts; 328 have no current acceptance. The latter divide by the *initial scan route*, not by inferred product value:

| Initial route | Files without current acceptance | Next selection rule |
|---|---:|---|
| Godot logic scan | 92 | Review initial failure and subsequent checkpoint receipt; run only unresolved or code-affected behavior with the required fixture and module timeout. |
| Godot GUI scan | 104 | Inspect each route; use a real display for visible interaction and raster claims. Headless parse or object state alone does not accept rendering. |
| Python scan | 25 | Recheck import/config/asset tools affected by changed inputs or code. Prior checkpoint passes alone do not establish current state. |
| Outside initial execution matrix | 107 | First identify whether the script is a live regression, optional balance/performance run, native probe, release check or historical one-off; use the specific guide before running. |

Sixty-seven of those 328 have `native=true` in `gd-inventory.json`; this flag overlaps the groups above and is **not** proof that each script requires the extension. The current workspace has no `test/native-build/project/bin/space_native.dll`. The DLLs in historical `test/artifacts/` are frozen evidence, not a current build. Native-required cases in `test/run.py` therefore need a current native build or a suitable Windows environment. Windows release portability also requires `subst` per `test/guides/release.md`.

This environment has Godot 4.6.3 and can run isolated headless tests, but `$DISPLAY` is unset and neither `Xvfb` nor `xvfb-run` is installed. The two edited planet UI fixtures still need actual GUI interaction and visual review. The branch has not established a clean Windows launch or cross-computer installation. `origin/main` advanced to `d2293ce9` for player-entry work handled by the original startup thread; that is separate from cleanup acceptance and does not merge this branch.

`hightech_scientists` remains a selectable crew job while its retired purchase/distribution APIs always return false (STATUS U-030). Its old test was removed after checking the active crew test guide and pause/scheduler coverage. The user decided to keep the job; its new function is yet to be specified. Removing the old test does not remove the job. No AI research migration or substitute bonus is authorized.
