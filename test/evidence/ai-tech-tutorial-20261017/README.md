# AI factory tutorial validation

- Base: `main@7350199bca810209f505561ddb7a5be1a7059bdd`.
- `catalog-check.log`: UI text table and contract validation, 2387 rows valid.
- `focused-headless.log`: six focused checks for the new tutorial text, `/秒` units, and estimated time before and during research; 6/6 passed.
- `gui.log` and `gui/*.png`: actual main-scene GUI validation, 28/28 passed. `00-choose-research.png` shows the research guidance and selectable estimates; `02-uranium-shortage.png` shows both input units and the per-resource shortage state. The other screenshots are the original captures from the same run.
- `headless.log`: the pre-existing broad tree suite reports three assertions still expecting singularity's former 60-second first level and 108-second next level. The current main configuration uses a 20-second first level. No gameplay configuration or unrelated baseline tests were changed in this tutorial patch.

Godot executable: `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`. Tests ran in an isolated project and user directory under `test/work/ai-tech-tutorial-20261017/`; no personal save was included.
