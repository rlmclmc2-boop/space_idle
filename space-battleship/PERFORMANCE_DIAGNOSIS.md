# 当前存档性能诊断（2026-09-30）

## Baseline/current

本轮只测量，没有修改正式玩法逻辑或现有优化。输入是第 82 关存档快照 `../test/work/performance-20260930/input-save.json`，SHA-256 为 `8b882f2774ee02c3ce63e2bc02edf51ad48e9a7c35a8d49d89103577f0280c1d`。测试使用隔离的工程和用户目录，固定随机种子 1701、窗口 1373×883、页面顺序 0/1/2/5/6/8。每页预热 60 帧，采样 300 帧，每帧手动推进 1/60 秒游戏时间。1 倍速和 2 倍速都关闭 VSync；分别运行不限帧和 60 FPS 上限。原存档没有被写入。旧报告见 `../test/work/performance-20260930/报告.md`。

| 页面 | 不限帧均值 ms | 不限帧 P95 ms | 60 FPS P99 ms | 60 FPS 最慢 ms | 2 倍速 P99 ms |
|---|---:|---:|---:|---:|---:|
| 装备 0 | 6.89 | 14.24 | 18.58 | 22.40 | 23.11 |
| 科研 1 | 8.44 | 15.04 | 19.76 | 22.51 | 23.00 |
| 反应炉 2 | 9.33 | 16.35 | 20.81 | 22.47 | 22.64 |
| 船员 5 | 7.15 | 12.76 | 16.94 | 20.99 | 28.77 |
| 星球 6 | 7.67 | 15.71 | 18.73 | 21.28 | 21.91 |
| 星系 8 | 6.83 | 11.24 | 17.19 | 17.93 | 25.02 |

限速均值接近 16.67ms 是调度结果，不能当作实际计算成本。无上限的同存档重放揭示每帧计算余量。带函数包装的复测用于归因；其均值比未包装版高 0.25–0.76ms/帧，P99 不作严格前后比较。表中的帧率基准取未包装运行。

| 页面 | 节点均数 | 对象均数 | 静态内存 MiB | 显存 MiB | 可见渲染对象均数 | 图元均数 |
|---|---:|---:|---:|---:|---:|---:|
| 装备 | 918 | 4401 | 135.5 | 262.4 | 3015 | 24025 |
| 科研 | 918 | 4444 | 137.5 | 269.3 | 7316 | 37646 |
| 反应炉 | 918 | 4479 | 141.1 | 276.2 | 4981 | 34842 |
| 船员 | 982 | 4703 | 145.2 | 277.6 | 3938 | 25370 |
| 星球 | 1430 | 5884 | 153.3 | 294.5 | 2954 | 46016 |
| 星系 | 1753 | 6463 | 156.8 | 345.2 | 3547 | 42933 |

页面依次打开并懒加载控件与资源，跨页节点/内存上涨不能直接判定泄漏。长跑固定船员页判断时间增长。

原始逐帧证据在 `../test/work/saved-diagnosis-v6j7igxl/`。文件名中的 `plain` 是仅采引擎指标，`detail` 增加函数计时、UI 事件和 trace；`fps60` 是限速。每个 JSON 的 `pages[].frames[]` 含逐帧指标，`pages[].traces[]` 含超过 20ms 和最慢帧。完整的新字段以 `validation-1-detail.json` 为准：每帧有 frame/CPU/GPU/process/physics/render、draw calls、渲染对象、图元、对象、节点、资源、内存、各模块函数及 `active_counts`（实体数或该帧活跃工作单元数）。测试入口是 `../test/saved_game_diagnosis.py`，汇总入口是 `../test/analyze_saved_game_diagnosis.py`。

## CPU/GPU/render split

| 页面 | 脚本主循环 CPU 均值 ms | Viewport 渲染 CPU 均值 ms | GPU 均值 ms | GPU P99 ms | 平均 draw calls |
|---|---:|---:|---:|---:|---:|
| 装备 | 2.56 | 1.44 | 0.27 | 1.71 | 388 |
| 科研 | 2.80 | 2.06 | 0.22 | 0.91 | 519 |
| 反应炉 | 2.91 | 2.16 | 0.43 | 2.30 | 566 |
| 船员 | 2.58 | 1.47 | 0.16 | 0.47 | 387 |
| 星球 | 2.63 | 1.68 | 0.35 | 2.31 | 472 |
| 星系 | 2.27 | 1.30 | 0.15 | 0.39 | 355 |

`cpu_ms` 是手动调用游戏主场景 `_process` 的实测时间；`render_ms` 是引擎的 viewport 渲染 CPU 加 frame setup；`gpu_ms` 是 Godot viewport GPU timer，均为每帧读取。渲染 CPU 可能包含自绘 `_draw` 的脚本时间，因此这几列不能直接相加。物理监视器约 0.01–0.04ms；游戏主要碰撞在 GDScript `tick_projectiles`，不属于引擎物理。

补测在 `process_frame` 与 `frame_pre_draw` 两个信号间直接计时，得到可逐帧对应的 `process_ms`；再加 viewport 渲染 CPU，作为 CPU 工作跨度的近似上界。带仪表补测各页均值如下，可能与表中未包装基线有 0.25–0.76ms 的探针开销，且引擎计时边界可能重叠：

| 页面 | process_ms | CPU 工作跨度近似 ms | GPU_ms |
|---|---:|---:|---:|
| 装备 | 5.81 | 7.27 | 0.29 |
| 科研 | 6.59 | 8.58 | 0.23 |
| 反应炉 | 7.41 | 9.47 | 0.47 |
| 船员 | 5.91 | 7.34 | 0.17 |
| 星球 | 5.99 | 7.55 | 0.34 |
| 星系 | 5.52 | 6.82 | 0.16 |

这也回答了“正常 6–9ms 花在哪里”：约 5.5–7.4ms 位于绘制前的脚本与引擎处理段，其中主场景脚本约 2.3–2.9ms；viewport 渲染 CPU 另约 1.3–2.1ms，GPU 小于 0.5ms。它们不是互斥 CPU profile 栈，不能用相减推断未覆盖函数的精确成本。

引擎 `Performance.TIME_PROCESS` 与 `TIME_PHYSICS_PROCESS` 监视器也逐帧写入 JSON，但其值按约一秒刷新，不可把相邻 JSON 行当作独立帧耗时。部分页面切换产生的旧值会在采样期重复；本报告不用该监视器做长帧归因。后续诊断脚本还记录 `process_ms` 为 `process_frame` 到 `frame_pre_draw` 的实测跨度，同时保留原监视器值为 `process_monitor_ms`。Godot 上游记录了监视器更新频率限制：[Godot proposal #6809](https://github.com/godotengine/godot-proposals/issues/6809)。GPU 和 viewport CPU 计时需要显式启用；API 说明见 [RenderingServer 文档](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)。

## Normal-frame cost ranking

下表来自不限帧、函数包装的 1800 帧。`count` 是所涉活跃实体的平均数量或说明的范围。`total_ms` 是该函数及其子调用的平均耗时；同一调用链会重复计入多行，百分比不能求和。`max_ms` 是单次调用最大值。

| 模块 / 代表函数 | calls/frame | active_count | total_ms/frame | max_ms | %frame |
|---|---:|---:|---:|---:|---:|
| render / `main.draw_battle` | 1.00 | 可见敌舰平均 6.85 | 2.419 | 11.770 | 29.5% |
| battle / `game.tick` | 1.00 | 敌舰 6.85、弹体 13.97 | 1.512 | 14.696 | 18.5% |
| simulation / `main.advance_game_time` | 1.00 | 1 个游戏状态 | 1.517 | 14.702 | 18.5% |
| projectile rendering / `main.draw_projectile_fx` | 25.47 | 弹体视觉 12.74 | 0.693 | 0.185 | 8.5% |
| enemy / `main.enemy_render_position` | 46.09 | 敌舰 6.85 | 0.387 | 0.065 | 4.7% |
| simulation / `game.advance_hightech` | 1.00 | 4 个科研项目 | 0.418 | 3.793 | 5.1% |
| projectile logic / `game.tick_projectiles` | 1.00 | 弹体 13.97 | 0.293 | 9.333 | 3.6% |
| animation / `main.advance_turrets` | 1.00 | 存档有 8 个武器槽 | 0.309 | 0.844 | 3.8% |
| stat / `crew_system.system_effect` | 2.90 | 存档有 20 名船员 | 0.300 | 0.214 | 3.7% |
| data / `game.active_research` | 1.00 | 4 个科研项目 | 0.293 | 0.492 | 3.6% |
| UI / `main.refresh_visible_cards` | 1.00 | 1 个可见页面 | 0.175 | 3.834 | 2.1% |
| effect / `main.draw_battle_particles` | 2.00 | 粒子平均 15.59 | 0.137 | 0.927 | 1.7% |
| collision / `game.hit_enemy` | 0.15 | 敌舰 6.85、弹体 13.97 | 0.088 | 3.072 | 1.1% |
| weapon / `game.jewel_fire` | 0.22 | 存档有 8 个武器槽 | 0.085 | 0.904 | 1.0% |
| text / `main.text_at` | 4.90 | 每帧文字绘制调用 | 0.041 | 0.533 | 0.5% |
| layout / `main.refresh_structure` | 0.007 | 船员页 99 个 Container | 0.019 | 5.914 | 0.2% |
| data / `game.save_progress` | 0.28 | 1 份隔离存档 | 0.077 | 2.980 | 0.9% |

函数追踪还覆盖船员、星球、装备 UI，以及武器、命中、属性与数据路径。活跃实体、对象、节点、资源数及内存随每帧保存；`active_count` 的 UI/布局项没有把节点数误当成刷新次数。

## Tail-frame analysis

### P95

1 倍速限速的各页 P95 为 16.73–16.91ms；2 倍速为 17.73–20.00ms。1800 帧合并后的 P95 门槛分别为 16.96ms 和 20.26ms。1 倍速 P95 群的主循环 CPU 均值 8.62ms，正常帧（≤17ms）为 2.68ms；`game.tick` 从 1.36ms 升到 5.61ms，`draw_battle` 从 2.36ms 升到 4.97ms，GPU 仅从 0.25ms 到 0.42ms。2 倍速 `game.tick` 从每帧 1 次变成 2 次，包装测得战斗逻辑从 1.56ms/frame 升到 3.08ms/frame；存档写入事件在同样 1800 帧中由 66 次升到 120 次。

### P99

1 倍速限速各页 P99 最高 20.81ms（反应炉）；2 倍速最高 28.77ms（船员）。1800 帧合并后的 P99 群中，1 倍速主循环 CPU 均值 12.57ms、GPU 0.30ms，2 倍速分别为 17.57ms、0.36ms。1 倍速 P99 帧出现 `save_progress` 的比例 33%；2 倍速为 61%。2 倍速船员页 30.20ms 的帧中，主循环 CPU 26.75ms、GPU 0.12ms、渲染 CPU 1.00ms，包含 `game.tick` 26.17ms、`crew_system.advance` 10.71ms、`game.advance_planets` 10.01ms、`game.save_progress` 9.99ms。这些内部调用重叠，不能求和。船员 UI 只写入 1 处文字，Container resize 为 0。1 倍速船员页 23.31ms 的帧中，`game.advance_planets` 9.85ms、`game.add_crew_exp` 4.51ms，GPU 0.20ms、Container resize 0。

### >20ms / >33ms / >50ms

限速详细采样的 1800 帧：1 倍速超过 20ms 为 29 帧，2 倍速为 98 帧；两次短采样均没有超过 33ms。持续船员页 15 分钟记录到 **31 帧 >33ms，最慢 48.75ms；没有 >50ms**。这 31 帧平均耗时 37.36ms，主循环 CPU 16.62ms，GPU 0.51ms，渲染 CPU 1.74ms。30 帧触发 `save_progress`（调用期间平均总计 5.77ms，单帧最高 25.58ms），26 帧触发 `change_state` 与 `refresh_structure`，25 帧触发 `crew_panel.refresh`，16 帧触发玩家受击。没有 Container resize、节点创建或释放，仅 5 次可观测文字写入。每个异常帧都保留了模块、UI、实例变化、draw calls、CPU/GPU 与对象数。旧报告的船员页 56.38ms 在本轮未重现，因此不能把那一帧的确切来源当作已确认。

### 具体触发原因/相关事件

1 倍速最慢帧的实测热点包括：装备页 25.62ms 时 `advance_jewel_repeats` 5.75ms 与 `jewel_fire` 5.36ms；科研页 23.11ms 时 `jewel_fire` 6.72ms；星球页 27.08ms 时 `advance_jewel_repeats` 7.34ms；船员页见上。2 倍速的高帧还出现 `tick_projectiles` 7–9ms、`advance_planets` 9–10ms，以及保存和船员经验结算。15 分钟长跑最慢的 48.75ms 帧包含 `tick_projectiles` 11.49ms、`hit_player` 9.13ms、`advance_planets` 10.39ms、`crew_panel.refresh` 5.23ms、14 次 `save_progress` 合计 4.35ms；GPU 0.15ms。另一帧为 38.08ms，`save_progress` 单次 25.58ms、主循环 CPU 35.19ms。长跑中 22/31 个 >33ms 帧的墙钟耗时，比“手动主循环 CPU + viewport 渲染 CPU”多 20ms 以上；这部分可能含引擎调度与未覆盖的原生工作，现有仪表不能单独归因。跨帧统计显示组合事件比单个常态函数更能解释 P99。

## A/B disable results

所有关闭开关只注入隔离工程副本；正式版本默认行为不变。以下是在相同存档、种子、页面顺序、预热/采样条件下运行的**不限帧六页均值差**。负值代表关闭后帧时间减少；数值是整段重放的净变化，不等于该模块独占耗时。战斗/弹体逻辑关闭会改变后续战况，所以只作上界和方向性证据。

| 临时关闭项 | frame_ms delta | 主循环 CPU delta | GPU delta | 船员页 frame delta | 解释 |
|---|---:|---:|---:|---:|---|
| battle logic | -5.31 | -2.28 | -0.11 | -5.50 | 停止 `game.tick`，战况冻结；上界 |
| projectile logic | -1.31 | -0.21 | -0.10 | -1.30 | 跳过 `tick_projectiles` 并清掉残留弹体，战况改变 |
| projectile logic/visual 中的 visual | -2.07 | -0.40 | -0.11 | -1.98 | 跳过弹体视觉推进和绘制；平均 draw calls 少约 89 |
| enemy visual | -0.46 | -0.03 | -0.02 | -0.10 | 跳过敌舰绘制；平均 draw calls 少约 13 |
| effects | -0.31 | -0.03 | -0.04 | -0.25 | 跳过粒子绘制和部分武器视觉 |
| UI update | -0.45 | -0.23 | ~0 | +0.13 | 跳过每帧可见卡片、导航与 FPS 更新；事件驱动 UI 仍运行 |
| text update | -0.22 | -0.02 | -0.02 | -0.20 | 跳过 `set_ui_value` 的文字属性写入；不覆盖所有直接赋值 |
| animation | -0.53 | -0.30 | -0.01 | +0.12 | 跳过炮塔和部分视觉节点 `_process`；反应炉页下降约 2.05ms |

额外渲染 A/B：在隔离副本中隐藏带 ShaderMaterial 的 CanvasItem（页面切换时发现 11–23 个，含已经隐藏的节点），相对同脚本复测的六页 GPU 均值变化为 -0.043 至 +0.004ms、frame_ms 变化为 -0.12 至 +0.18ms。它关闭的是整层画面，不是纯 shader 指令；结果仍未显示这类层是当前长帧主因。

## Rendering analysis

当前为 Godot 4.7.2、OpenGL Compatibility、RTX 3090。不限帧平均 draw calls 355–566，P99 最高 864；渲染对象均值约 2954–7316，图元约 17k–46k，具体逐帧见 JSON。GPU 帧均值 0.15–0.43ms、P99 最高 2.31ms，明显低于脚本/渲染 CPU 与长帧时长。当前条件下**不是 GPU bound**。`draw_battle` 的脚本构图均值 2.42ms/frame、最高 11.77ms；弹体视觉 A/B 同时降低渲染对象约 1934、draw calls 约 89，但 GPU 仅降 0.11ms。主要成本在 CPU 侧的绘制命令生成/提交与战斗逻辑。

工程有星空、反应炉、星球及星系等 shader，战场有半透明辉光/粒子。现有 GPU 计时、effects/enemy visual A/B 与 shader 层隐藏实验均不支持“GPU shader 或 overdraw 导致当前长帧”的判断。隐藏整个 shader 层不是纯 shader 运算 A/B；要量化单个材质仍需固定画面逐层替换材质。透明层的 overdraw 没有独立 GPU 像素计数，不能宣称成本为零。

## UI analysis

限速详细采样中，主场景每帧平均 `queue_redraw` 请求约 2.75 次，实际 CanvasItem `draw` 信号约 5.45 次；2 倍速分别约 2.80 和 5.60 次。记录到的文字属性变更分别为 84 次和 169 次/1800 帧。船员页 1 倍速 300 帧中有 7 次文字变更，仪表覆盖的 UI 刷新调用约 4.39 次/帧、含子调用总计 0.626ms/帧；平均 3 次主场景 redraw 请求、约 3.05 次 CanvasItem draw，Container `resized` 事件和节点增减均为 0。船员 `refresh_visible_cards` 平均约 0.06ms，`crew_panel.refresh` 虽偶发触发，短采样单次最大约 2.7ms。已观测的 20–30ms 船员长帧由战斗/星球/经验结算主导，没有测量证据指向布局重排。科研页 UI 刷新含子调用约 1.215ms/帧，为六页中最高；反应炉页 CanvasItem draw 信号约 14.73 次/帧。

长跑的 31 个 >33ms 帧中，26 个执行 `refresh_structure`（触发帧平均约 3.6ms），25 个执行 `crew_panel.refresh`（触发帧平均约 2.8ms）。这说明状态切换时 UI 同步刷新是长帧的一部分，但 48.75ms 最慢帧的主要脚本段还包含战斗受击、星球推进与保存。`resized` 是 Container 布局变化的代理指标，不是 Godot 内部 `sort_children` 的完整次数；直接 `.text=` 写入也不全经过 `set_ui_value`。因此 UI 文本与布局结论限于这些可观测路径。逐帧 trace 保存 `ui_writes`、`redraw_requests`、`draw_events`、`layout_events`、`nodes_added/removed`。

## Long-run trend

持续船员页测试在同一隔离重放中运行，每个时间点用最近 300 帧统计。页面和采样方式保持不变；游戏自然从第 82 关推进到第 83 关，所以 15 分钟的实体密度变化不能全归因于时间。探针连接的 draw/resize 信号包含在连接数中。

| 时间 | frame 均值 ms | P95 ms | P99 ms | 最慢 ms | 内存 MiB | 节点 | 对象 | 弹体 | Timer | 信号连接 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0min | 16.61 | 16.74 | 18.16 | 24.47 | 178.17 | 1753 | 6461 | 23 | 1 | 5725 |
| 5min | 16.61 | 16.85 | 18.40 | 23.51 | 183.19 | 1753 | 6462 | 29 | 1 | 5725 |
| 15min | 16.61 | 16.65 | 21.54 | 30.93 | 182.85 | 1753 | 6465 | 29 | 1 | 5725 |

节点、Timer、信号数不增长；内存先升约 5MiB 后略降，对象数仅 +4。没有单向持续增长的证据。15 分钟 P99 稍高，同时关卡与敌舰数改变，不足以推断时间型退化。长跑中 >33ms 的原始帧保存在 `../test/work/saved-diagnosis-v6j7igxl/longrun-1-fps60-detail.json` 的 `long_run_traces`。

## CONFIRMED bottlenecks

1. **CPU 侧战斗更新和战场绘制是常态成本主项。** `game.tick` 1.51ms/frame、`draw_battle` 2.42ms/frame，GPU 均值仅 0.15–0.43ms；battle logic 关闭的净帧差为 5.31ms，但该差值包含战况冻结的间接影响。
2. **2 倍速放大尾帧，是双 tick 和更多同帧事件所致。** 每帧 `game.tick` 由 1 次变 2 次、平均耗时约翻倍；限速 1800 帧中 >20ms 从 29 次增至 98 次，船员 P99 从 16.94ms 升至 28.77ms。
3. **弹体视觉有可测 CPU/渲染命令成本。** 关闭后的六页净帧差 -2.07ms、draw calls -89、GPU 仅 -0.11ms。具体独占成本小于净差所示，因为重放状态和引擎调度也参与变化。
4. **持续运行的长帧与同步结算事件同帧出现。** 31 个 >33ms 帧中 30 个执行了保存，26 个执行状态切换/结构刷新，16 个执行玩家受击；保存单次最高 25.58ms。最慢 48.75ms 帧同时含受击、星球推进、船员刷新和多次保存。实测证据只支持这些事件共同贡献，不支持把全部 48.75ms 归给某一个函数。

对应位置：`scripts/main.gd` 的 `draw_battle`（约 2361 行）、`advance_projectile_visuals`（约 1266 行），`scripts/game.gd` 的 `tick`（约 2156 行）及 `tick_projectiles`（约 2297 行）。当前测量给出的常态上界分别为 2.42ms/帧战场构图、1.51ms/帧战斗更新；弹体视觉关闭的整段净差为 2.07ms/帧，但不是可直接兑现的优化收益。本轮不改这些位置。

## SUSPECTED

- 船员页既往 56.38ms 长帧可能属于本轮 48.75ms 附近的受击、星球/船员结算与保存组合，也可能含额外调度延迟。15 分钟内没有 >50ms；下一步在真正跨过 50ms 时保存线程/系统级时间线，才能确认既往尖峰。
- `game.save_progress` 在一般帧约 2ms，2 倍速船员 30.20ms 帧中达到 9.99ms，并与 `advance_planets`、`crew_system.advance` 同帧。下一步验证：对触发保存的事件按原因标记，比较保存前后文件大小及同步写盘时间；不应先改保存逻辑。
- 分配/回收可能放大结算峰值，但目前无法确认为主因。1 倍速 >20ms 帧静态内存比前帧平均多约 72KiB，普通帧约 13KiB；2 倍速分别约 57KiB 和 12KiB。短采样长帧没有新增或释放节点，也没有 >1MiB 的单帧内存跳变。下一步用引擎内存分析和事件级对象创建计数区分短命对象、缓存扩容和回收；这些内存变化不能直接解释耗时。
- GPU overdraw / 单个 shader 的准确成本尚未单独隔离。已隐藏全部带 shader 的画布层，GPU 变化低于 0.05ms；下一步若需区分某个材质，应固定画面逐个替换星空、反应炉材质和透明辉光，比较 GPU timer 与 draw calls。

## EXCLUDED

- **当前存档下 GPU 吞吐主导。** GPU P99 最高约 2.31ms；已观测 20–30ms 帧通常由 CPU 事件驱动。
- **引擎物理。** 物理监视器约 0.01–0.04ms；游戏弹体碰撞在脚本，不在物理引擎。
- **常态船员布局重排。** 船员页短采样 Container resize 为 0，已观测长帧没有节点实例化/释放；这不排除更稀有事件。
- **本次 15 分钟内的节点或信号泄漏。** 节点 1753、Timer 1、信号连接 5725 均稳定；对象仅从 6461 到 6465，内存没有单向上涨。不能据此排除更长时间或其他存档的增长。
- **带 shader 的画布层主导当前 GPU 帧耗时。** 隐藏这类层后 GPU 均值最多减少 0.043ms；该 A/B 包含整层视觉效果，不能推出每个 shader 指令的独占成本。

诊断脚本和 A/B 注入只存在于 `../test/` 及其隔离副本。下一轮优化应优先依据本报告的逐帧事件和可复现 A/B，另行验证收益与行为一致性。
