# Current branch production handoff check (2026-10-16)

Compared tested mixed-art integration `25fa50757ad4317f2d0a5c34154f11ccc26a81d7` with branch tip `3608cda327fb32e5369c4666ae89026bc06d599b`. All production deltas: `config_excel/enhance_config.xlsx` and projected `data/game_data.json` restore `memory_heal_fraction=0.01` and `memory_buffer_fraction=0.1` after deferring the global memory change; `config_excel/unlock.xlsx` and its JSON projection revise opening tutorial descriptions; `data/ui_text.json` revises onboarding and enemy-defence hints; `scripts/beginner_guide.gd` fills available weapon slots, then defence, before the paid upgrade cue; `scripts/native_execution_compiler.gd` normalizes authored reactive integer fields for native descriptors. No native C++ source or asset change from the tested commit. Test and documentation files form the remaining diff.

Evidence by production delta:

- Current enhancement workbook projects exactly into JSON (`python -X utf8 test/test_enhance_config.py`, pass; 68 authoring rows). Recovery pacing test after restoration recorded 22 checks, 0 failures in `../memory-main-revert-20261016.txt`. This is a scope deferral, not proof that high global recovery is balanced.
- Current unlock workbook projects exactly into JSON and passes `validate_projection` (direct `read_rows`/`convert_sheet` check, 46 records). Current beginner guide: 54 checks, 0 failures (`current-guide.log`). Earlier visual captures and help-entry evidence are in `../beginner-guide-20261016/`.
- Reactive descriptor normalization: `reactive-native-schema.md`, `native-reactive-descriptor.log`, and `native-reactive-event-after.json`/`.log` verify native admission and authored reactive changes in the same 3-3 encounter. Native C++ source and assets remain byte-identical by Git diff from `25fa5075`.
- Mixed-art pacing: `balance-art-mixed-uncapped-recovered-bracket-{before1,after,before2}-full-frame.json` uses identical 240 logic steps, 777 fires, 4508 hits, and stable before endpoints. The four-second full-frame sample shows no material regression, but does not validate long-run gameplay.

Native source build: copied current tracked `addons/native_battle/SConstruct` and four `src` files to isolated D: directory. Clean SCons compile/link succeeded with pinned `godot-cpp` commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`, verified Godot 4.7.2 API SHA256 `d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`, D: LLVM/MinGW toolchain, `template_release`, `-j 1`. Output DLL SHA256 `a5517d8fcdb162fabbe89b2e15fe77e98d25cca3f072ed8cf20f0fc5c2147ad3`; this fresh DLL was installed only in task-local isolated test staging. Prior visual bracket used SHA256 `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b`. Build artifacts remain ignored under `test/work`; no DLL is committed.

Current-branch visible startup checks, using Godot 4.7.2 on D:, isolated project/user data, save disabled:

- Stage 1 `main.tscn`: 60 scene `_process` steps, exit 0, `STAGE1_MAIN_OK`; no script error in `current-stage1-main-smoke.log`. Reproduction script: `current-stage1-main-smoke.gd`. Current guide separately passed 54/54.
- Stage 2, authored point 5: 120 steps, `native_active=true`, `handoffs=0`, exit 0; no script error in `current-stage2-native-opening.log`.
- Stage 3, authored point 5: same 120-step native gate, exit 0; no script error in `current-stage3-native-opening.log`. Both cases use the freshly built DLL and legal stage equipment.

An older `test_battle_transition_ui.gd` cannot serve as the stage-1 smoke: it accesses removed `jewel_panel` on `battlefield.gd` and timed out. Its failure is in test code after scene startup. The minimal stage-1 script above verifies the requested startup without that stale property. The import logs also emit the established nested `tools/result_analyzer/project.godot` warning, without fatal import failure.

**Handoff conclusion:** Ready for parent review and merge decision for the opening integration, guide, reactive native admission, and bounded visual regression. No main merge performed here. Global memory rate reduction and longer progression/resource pacing remain outside this opening merge's validated scope. Parent should reread parent-owned `PROJECT_CONSTRAINTS.md` before acceptance.
