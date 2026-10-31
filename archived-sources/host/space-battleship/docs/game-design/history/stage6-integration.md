# 第6阶段历史：页面/保存恢复与生命周期

[唯一入口](../README.md) → [当前验收边界](../11-stage6-contract.md)。以下按原记录保留提交/平台/版本；其中“当前/待复审/已通过”只属于当时构建，不能覆盖新的模块验收。旧探针名是证据标识，不是当前运行命令。

## 历史最终验收结论（7e2c7d2a双审通过）

7e2c7d2a已通过父线程云端真实窗口验收及独立Astra高审核：顶部停止/保存失败提示、四种余额、防御与统计互不遮挡；实际`_process`与布局探针通过，未发现新阻断。此前审核阻断均已闭环，已确认范围准予正常合入main。此次仅同步验收记录，不新增功能或测试。

| 已完成验收 | 证据及范围 |
|---|---|
| 独立审核 | 截至29dc6f86，先前保存恢复、改造预览/重复确认、跨模式奖励、共享几何/炮口、遭遇切换越界、四余额HUD及生命周期阻断均逐项复核通过。包含6次遭遇绘制、超空间10波、6会话释放、8次替换稳定与正常退出无泄漏。7e2c7d2a的停止/保存错误提示经独立Astra高实际`_process`及布局探针复核通过。 |
| 父线程云端真实键鼠 | 新档首关战斗/通关；页签；科研编辑与保存/加载；目录选择；29dc6f战斗再出击清除敌舰/炮台、返回离港且保留余额；首波铁13与后续铁29可见且不被防御遮挡；正常退出无泄漏；7e2c7d2a真实窗口确认停止/保存失败提示、四余额、防御及统计互不遮挡。 |
| 后期页面 | 星球、星系地图等使用后期可用性夹具实测，不能记作自然打到60关。 |
| 测量边界 | 最新资产版Windows性能和实际音效未在云端验证。下方旧本机GPU/倍速测量仅属于其历史构建，不代表最新资产版或全面跨平台保证。 |

下文为有版本范围的实现与测量历史，不是当前待办；其中当时未完成的项目，以本节最新状态为准。本轮双审已通过，按已授权范围执行正常main合并；合并不扩大下述测量与自然流程覆盖边界。

## 历史：977e602玩家页面集成候选

The working branch `rewrite/stage6-finalization` now connects hull/turret art, opening/starfield scenery, six bridge pages, planet appearance, the galaxy map and traffic, enemy/tutorial archives, and native attribute details. Hyperspace has route/warehouse/forge/filter tabs with named selections, drone details, sealed release and overflow organization. Reforge uses planet/drone selections and the existing preview/confirm transaction. Gameplay, Excel values and save formats are unchanged.

Targeted evidence: `_stage6_startup_probe.gd` passes initial on-disk save, localized names, hidden locked features, research wrapping, paused autosave, resume and corrupt-primary recovery. `_stage6_page_probe.gd` passes existing page/import/reforge/research interactions. `_stage6_window_ops_probe.gd` passes pause/guidance, bridge return, file picker, visible save error and notification actions against the new tabs. `_stage6_bridge_probe.gd` advances the production Session into combat (22.4 game seconds) and checks six pages plus four hyperspace subpages at572×960 with no horizontal overflow; its forced-visibility fixture verifies layout, not unlock progression. Independent focused probes verify30 map nodes with transport/explorer vessels, pause and snapshot isolation; native query purity, return-copy isolation and upgrade synchronization; and hyperspace filtering, storage browsing, gate rejection, release and organization.

Local OpenGL captures were inspected before the later instruction to keep execution in the background; subsequent local verification is headless. At977e602 these checks preceded parent cloud play and the requested independent reviews; subsequent outcomes are recorded in the current ledger. That candidate reported retained Texture RID/ObjectDB resources; the later lifecycle correction below identifies and fixes the game-owned cycle. The embedded file-picker focus diagnostic remains separate from ownership. Screenshots, temporary focused probes, generated data, native binaries and saves stay outside Git.

## 历史：911ab0d修复977e602审核问题

The977e602 review failed on the following five items. The911ab0d increment corrected them; the later independent review closed these items, as recorded above. All follow-up verification below is headless, as requested.

| Finding | Correction and targeted evidence |
|---|---|
| Import envelope missing`configHash` throws instead of rejecting | SaveFiles shares complete required-envelope validation with Session import/candidate admission. `_stage6_page_probe.gd` removes each of8 required fields and verifies rejection plus preservation of the live session. |
| Both save pointers corrupt: confirmed new game cannot publish | Preview names a separate`new-game-<hash>` child store and states that original files are preserved. Confirmation writes and reads back the candidate before replacing the live game. `_stage6_startup_probe.gd` verifies a real failed candidate write preserves the live game, retry publishes, all4 original pointer/slot files remain byte-identical, and restart loads the new store. |
| Finished`DataWrite` failure blocks directory migration | Explicit migration distinguishes a still-busy writer from its historical result. The startup probe creates a real slot-path collision, observes`DataWrite` with the writer drained, then migrates and successfully publishes to a writable directory. Existing close/import failure semantics remain. |
| Forge confirmation can execute a different selection or repeat payment | `_stage6_forge_confirmation_probe.gd` checks operation/target/parameter/drone changes and external form changes invalidate the bound forecast; confirmation checks the source and forecast again. One preview owns one operation ID; repeated confirmation preserves wallet, drone and RNG, while a new preview can intentionally repeat the action. |
| Mainline sortie can replace an active manual challenge and misattribute kills | Session's`start_campaign_sortie` rejects active manual mode; Campaign's direct entry also rejects its hyperspace state. `_hyperspace_runtime_probe.gd` checks both entries leave campaign, receipt and native state unchanged, then completes the real10-wave challenge and credits its reward once. |

`_stage6_hud_probe.gd` verifies current/maximum shield and armour labels, safe fractional bars at zero and extreme capacities, friendly small numbers, and Chinese damage-source names. The initial84-pixel drawing-only enlargement in911ab0d was rejected because it split art and collision. It is superseded by the shared geometry correction below. HUD queries remain read-only; opaque-region turret crops use the authored textures. The archive now owns full damage breakdown; the battle summary stays bounded.

Fixed guidance distinguishes timed drops from ordinary enemy drops, states attack-birth snapshots correctly, and requires an unconquered planet with a completed shipyard for reforge. Removed the unused equipment-detail query, write-only selected-section field and redundant hull-colour fallback. No new local real-window acceptance is claimed; the game-owned exit resource cycle is corrected below.

## 历史：01ab49共享几何及会话生命周期修复

Player alpha height now equals the existing resource`static_height × player_display_multiplier × playerVisualScale*`; initial Frigate height is97.825 logical pixels. Enemy configured width/height are normalized against the same alpha hull bounds. The resulting vertices are consumed unchanged by drawing and native collision. Turret cropping, authored port coordinates and fixed forward mount pose produce one source-keyed world port for both numeric and screen births. There is no independent84/60-pixel draw enlargement. Damage, cooldown, root timing and other combat formulae are unchanged; corrected envelope dimensions necessarily determine their actual contact positions/times.

The current native binding uses`input_geometry` and`input_ballistic_geometry` with the same stable-ID muzzle dictionary. The old optional presentation-muzzle API documentation described a removed binding and has been corrected. Native`geometry_details()` is a read-only observation of committed hulls/ports and actual active-flight launch/motion fields; it is used by targeted verification, not the frame loop.

`_stage6_geometry_contract_probe.gd` verifies all5 authored player size paths, player/enemy rendered hull equality to actual native hulls, visible/numeric/screen muzzle equality, real retained pulse and hostile-cannon births, and an independently calculated ray/polygon contact: no damage0.0005 seconds before3.315833435, damage after the next0.001 seconds. Existing combat and cannon oracles still pass their damage, timing, single-drop and survival assertions. `_stage6_hud_probe.gd` now checks the shared97.825-pixel size instead of the rejected separate enlargement.

Exit diagnostics were a real Session ownership cycle: Session owned modules whose4 tutorial lambdas captured Session. Capturing only the local Tutorial owner removes the back-reference without introducing a disposal framework. Before the correction,6 discarded sessions stayed alive with+26 ObjectDB objects each. `_stage6_lifecycle_probe.gd` verifies6 sessions and retained BattleView ownership release, all4 tutorial callbacks,8 real load/new-game replacements with stable warmed resource/object/node counts, then actual`main._close_game()`. The final integrated run exits0 without ObjectDB/resource/Texture RID diagnostics. Later parent cloud play and independent checks are recorded in the current ledger.

## 历史：29dc6f修复遭遇切换及资源HUD

The reviewed candidate retained enemy weapon descriptors/poses after native actor teardown. Battle now retires encounter-owned enemy descriptors, ports and pending visual feedback at sortie reset and retreat transitions, then rebuilds from the post-transition native owner. New wave descriptors retain source UID and resolve against current actors, including native slot/storage reuse. `_stage6_encounter_presentation_probe.gd` uses the real Session sortie command, native wave start, lethal-hit retreat and manual-hyperspace return, exercising Node2D drawing6 times with no stale enemy pose or actor-index error. The extended hyperspace runtime probe also verifies enemy presentation retirement after successful10-wave return and retains its single-reward assertions.

The wallet was still drawn at y795 beneath the new defence card. BattleHud now owns all three fixed, disjoint regions: defence708–830, resource grid838–894 and statistics902–927; four currencies wrap into2 columns ×2 rows. Economy exposes cached display-row copies and its view retains only drop drawing/pickup. The former standalone statistics view is removed. `_stage6_hud_probe.gd` credits all4 currencies with extreme Amount values, measures each label using the production Chinese font, and checks cell containment, pairwise separation and no text overflow. Local follow-up was headless; parent cloud play later verified wallet visibility and repeat-sortie behavior in29dc6f86.

The lifecycle probe now releases its own2 coroutine-local ShaderMaterials before closing the tree. A separate verbose run identified the remaining4 objects/2 resources as active Ogg playback and its stream, not materials. Main now stops its own music/effects players and clears their stream references before interface replacement and successful close. The final integrated replacement run keeps resources at86 and nodes at1031 through8 replacements and closes without ObjectDB/resource/Texture RID diagnostics; probe-local materials and production audio ownership are distinguished from the earlier Session cycle fix.

## 历史功能覆盖（977e602之前的阶段记录）

| Area | Evidence |
|---|---|
| S01/S02 async save, generation, dirty state and write failure | `_save_files_probe.gd`, `_stage6_session_probe.gd`, `_stage6_page_probe.gd`. Frozen initialization config hash, stale candidate generation, backup, writer failure and retry are asserted. |
| S03/S04 candidate validation and live-session preservation | Session and page probes reject malformed checksum, state, filter and configuration. Import confirmation persists the unsaved old session first; failed backup keeps it live, failed candidate write is visible and retryable. |
| S05/S06 checkpoint, offline and time recovery | `_stage6_checkpoint_probe.gd` and `_stage6_session_probe.gd`: native history/ID watermark, rebuilt battlefield, pending drops, paid time, pause reasons, tutorial and offline credit. |
| Configuration publication and startup | `config_tools/hyperspace_parameter_contract.json` is read by the compiler and GameSession. All 40 registered keys have type, magnitude and applicable range checks. Fixed values, hard caps, authored-stage references and capacity relations are checked by both entries. Affix and legendary random intervals must contain a value on the configured sampling lattice, with both indices inside the signed 32-bit `randi_range` bounds. Invalid workbook publication preserves the active JSON. Invalid startup and import config is rejected before gameplay initialization. The publication suite and session probe verify both runtime paths. |
| Player pages and controls | `_stage6_settings_probe.gd`, `_stage6_page_probe.gd`, `_stage6_window_ops_probe.gd`: separate settings, new-game keep/reset, guidance pause, notifications, save and import, growth/return and file picker. The real-window probe isolates player settings. |
| Native battle presentation | Receipts carry settled Amount damage into bounded labels. C01 manual oracle, single death/drop and no-target assertions run against the same native kernel as the game. |

### Research investment UI and file persistence verification (2026-10-27)

Baseline: `8f0ee5ab4694ec4a8d075ce6d5df0ea0c448826f`. The investment panel previously initialized both resource inputs to zero and the automatic checkbox to false, and did not observe automatic budget refreshes. The existing save format retains these fields; this conclusion is now verified through actual files, rather than inferred from `save_state`.

The existing `_stage6_page_probe.gd` now sets automatic investment true, ratio 0.125, iron `1e400`, uranium `25`; presses the real Save control; waits for the writer; decodes the committed active envelope; loads that file through `Session.load_candidate`; exercises Load backup and Preview/Confirm import; and compares both restored business values and the rebuilt panel. All pass (`RESEARCH_DISK_FIELDS_OK`, `RESEARCH_FILE_LOAD_OK`, `RESEARCH_RESTORED_BACKUP_LOAD`, `RESEARCH_RESTORED_FILE_IMPORT`). A second actual file round trip verifies automatic false, ratio 0.123456 and both investments zero (`RESEARCH_DISABLED_ZERO_FILE_LOAD_OK`). No persistence schema or business rule change was needed.

The research owner now exposes the actual investment settings and notifies the panel after restore, manual apply and automatic budget refresh. The panel follows actual values while idle, preserves unapplied edits during refresh, shows current effective values separately, retains invalid input for correction, and offers an explicit reset to current settings. The probe exercises live refresh (800/1600 income at 12.5% gives 100/200), draft preservation while backend settings change (25% gives 200/400), apply, invalid input and reset (`RESEARCH_LIVE_REFRESH_DRAFT_APPLY_OK`). The full existing page probe ends `STAGE6_PAGE_PROBE_OK`, exit 0. This historical run reported shutdown cleanup/certificate diagnostics; later lifecycle fixes and cloud verification supersede that incomplete acceptance state.

UI/help wording now distinguishes the staffed AI factory job's automatic research continuation from the automatic-investment checkbox's periodic budget refresh. Iron and uranium use one common ratio; applying a ratio does not immediately recompute investments. The staffing requirement and 60 game-second refresh remain unchanged. Old help text claiming independent ratios or immediate recomputation was corrected.

At this early research increment, external play had not yet occurred. Later parent cloud checks verified research editing, file dialogs and persistence before main integration; their actual scope and remaining measurement limits are listed in the current ledger.


### Player-facing startup repair increment (2026-10-27)

Follow-up to cloud play on `411cfa9`: unlock prompts and archives now resolve configuration titles/descriptions instead of exposing notification keys; campaign states, wallet resource names, settings and save controls use Chinese player text. Research help/current values wrap within the growth viewport. Locked research, reactor, enhancement, crew, planet, galaxy, hyperspace and reforge sections follow the existing domain availability predicates. Visibility does not change unlock rules or stop hidden domain systems.

Normal startup now creates a default save directory beside the independent settings file (`user://saves` without a settings-path override), writes an initial snapshot, and resumes the valid primary save on later starts. The default autosave interval is 60 real seconds; an explicit saved interval of zero stays off. Chosen save directories persist in backward-compatible optional `saveDirectory` settings. Window close requests take a final snapshot with a bounded 2000 ms writer wait; failure leaves the game open with a visible warning. A damaged primary or orphaned save slot pauses recovery without configuring an overwriting writer; backup/import/new-game actions remain explicit.

Validation: existing `STAGE6_PAGE_PROBE_OK` and `STAGE6_SETTINGS_PROBE_OK`, plus `STAGE6_STARTUP_PROBE_OK`, all exit 0. The startup probe reads the actual initial file, checks fresh locked panels and Chinese prompts/resources, publishes a real progress update, measures wrapped research layout at the 572x960 viewport (growth 410x615, research 402x473), verifies paused wall-clock autosave and normal resumption of the same session, corrupts the primary pointer and confirms no overwrite, explicitly recovers the backup, and preserves disabled autosave. This historical startup run reported certificate/cleanup diagnostics. Later lifecycle fixes and parent cloud checks are recorded above.

Historical presentation audit at14e5218: 05 architecture section6 requires reuse of static assets, baked hulls, shaders, particle/audio assets, planet appearances and galaxy traffic. Baseline Battle loads hull images but uses them only for normalized outlines (`battle.gd` model loading); `draw_player_hull`/`draw_enemy_hull` draw solid polygons, while Main draws a solid background. BattleView connects retained native projectiles, contact shaders and beams, but does not instantiate existing ship/background presentation resources. This is incomplete asset integration, not a Linux fallback and not a design allowing final placeholder art. The later977e602 integration connected these assets/pages, and the subsequent increments and review results are recorded above; this early startup increment was not full-game acceptance.
