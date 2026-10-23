# Remaining test audit scope

`test-status-current.csv` lists every tracked top-level `test_*.gd` and `test_*.py` file and separates current receipts from the initial scan. After retiring `test_crew_scientists.gd` and moving the import recovery worker under `test/fixtures/`, it contains 344 files. Nineteen have current acceptance; 325 have no current acceptance record. The latter divide by the *initial scan route*, not by inferred product value:

| Initial route | Files without current acceptance | Next selection rule |
|---|---:|---|
| Godot logic scan | 91 | Review initial failure and subsequent checkpoint receipt; run only unresolved or code-affected behavior with the required fixture and module timeout. |
| Godot GUI scan | 102 | Inspect each route; use a real display for visible interaction and raster claims. Headless parse or object state alone does not accept rendering. |
| Python scan | 25 | Recheck import/config/asset tools affected by changed inputs or code. Prior checkpoint passes alone do not establish current state. |
| Outside initial execution matrix | 107 | First identify whether the script is a live regression, optional balance/performance run, native probe, release check or historical one-off; use the specific guide before running. |

Sixty-seven of those 325 have `native=true` in `gd-inventory.json`; this flag overlaps the groups above and is **not** proof that each script requires the extension. At the time of this audit, the workspace had no `test/native-build/project/bin/space_native.dll`. The [historical DLL snapshot](https://github.com/rlmclmc2-boop/space_idle/tree/d71bd1d26d9d3a5005a891b684de531966fdab1c/test/artifacts) was frozen evidence, not a current build; this retired directory is no longer an execution source. Native-required cases in `test/run.py` need a current native build or a suitable Windows environment. Windows release portability also requires `subst` per `test/guides/release.md`.

This environment has Godot 4.6.3 and can run isolated headless tests, but `$DISPLAY` is unset and neither `Xvfb` nor `xvfb-run` is installed. The parent ran both edited planet UI tests on a real X11 display: dialog layout 97/97 with scoped capture review (`parent-gui/README.md`), and the final reward UI 30/30 with the actual embedded bonus modal and reactor capture reviewed (`parent-gui/FINAL.md`). The branch integrated `origin/main` at `8dead1ed` without file conflicts; the resulting player-entry unit suite passed 17/17. This does not establish a fresh Windows or cross-computer launch of the combined cleanup branch.

`hightech_scientists` remains a selectable crew job while its retired purchase/distribution APIs always return false (STATUS U-030). Its old test was removed after checking the active crew test guide and pause/scheduler coverage. The user decided to keep the job; its new function is yet to be specified. Removing the old test does not remove the job. No AI research migration or substitute bonus is authorized.
