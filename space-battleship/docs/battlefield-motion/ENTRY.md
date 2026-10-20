# 战场动态化：唯一任务入口

## 基线与边界

- 仓库：`rlmclmc2-boop/space_idle`；2026-10-20 核实远端 `main` 为 `24f0751d5acd698eeb06d8ec7f0eb02e34a09e94`。任务从该提交建立独立检出及 `feat/battlefield-motion` 分支。
- 规范入口：仓库 `AGENTS.md`。本文件是本任务目标、实现索引、验收证据和剩余问题的唯一入口。
- 仅在此独立工作区实施和验收。远端 `main` 已包含启动修复 `d2293ce92733766b51bd1aa4f54bec6ea265fd0f`，本分支从其安全继承；不混入其他线程未验收改动，不争用运行中游戏实例。不重复全仓审计，不用 Library，不上传存档、凭据或缓存。
- 同一线程依次完成统一显示姿态与锚点、全舰航行、事件演出。不新增子任务或独立复测线程。最终交付代码、必要测试、测量、游戏截图和提交 SHA，等待 `main` 合并批准。

## 完整目标

在现有竖版自动战斗中，通过持续航行、各舰微小稳态修正，以及开火、受击、入场、死亡的事件响应，让战场有重量和动态。不得实现玩家机动系统，不改变阵型或玩法；不能用摇摆原型替代完整效果。

## 实现及验收约束

1. 保留原有逻辑站位、碰撞几何、目标选择、射击频率、伤害、命中时刻、死亡、掉落和关卡推进。显示姿态不得写回逻辑位置或污染战斗随机数。固定种子与相同输入下，动态开关两侧战斗结果必须一致。
2. 每舰每显示帧只计算一份平移和微转姿态，共享给舰体、固定底座、旋转炮台、护盾、推进器和附着特效。缓存舰内几何及锚点，只转换少数显示点；不扫描轮廓、重建包围盒或重算碰撞。纯动态引起的舰体几何重建、重新烘焙及全局布局重算次数必须为零，以新增计数证据证明。
3. 优先变换现有缓存画面或绘制实例，不拆大量节点，不重构战斗底层，不重建三维模型、阴影、材质。不得逐帧创建 Tween、计时器、节点、材质或临时几何数组。显示偏移不得触发装备、布局、统计或几何失效链。
4. 舰体、炮台、可见炮口、弹道和命中点统一对齐。炮台世界瞄准角须转为舰体局部角，避免重复旋转。炮弹从发射瞬间可见炮口出发，离膛后不跟随发射舰；仅对显示轨迹做连续、限幅的端点偏差补偿，不改逻辑弹道。导弹沿用原追踪规则，只调整显示目标点，不重新寻敌。光束两端绑定当前可见炮口与目标锚点。命中特效随舰体局部锚点。覆盖目标死亡、切换、跨波、暂停恢复和加速，不得明显打空却扣血、悬空光束或弹道跳变。
5. 舰体运动不同步、无逐帧随机抖动。参数起点：我方横移 2～4 像素、纵移 1～2 像素、偏航约 ±0.3°、周期 7～11 秒；敌小舰 3～6 / 1～3 像素、±0.6°、4～7 秒；精英与 BOSS 1～3 像素、±0.2°、9～15 秒。根据实际舰体尺寸、阵位间隙和长舰首尾位移限幅，避免绕行或重叠。使用固定独立相位，使偏航与横移协调。
6. 普通射击以炮台短促后坐为主，重武器可有微小舰体反冲；密集射击及受击合并并限幅，不影响结算。护盾优先局部反馈，重击才产生小幅舰体偏移。入场沿本舰站位后方短距离减速归位，不改变可攻击及出手时间。死亡逻辑立即移除；短暂残影仅属表现，限数量并复用。
7. 背景仅两层低对比缓慢流动，推进器小幅亮度及长度变化，不扩大遮挡；无全屏持续震动或新增实时三维光影。血条和名称跟随位置但不随偏航旋转；飘字从可见命中附近出发后独立运动。拾取须逆变换回原几何；裁剪创建时预留最大偏移余量，不逐帧重算精确边界。
8. 显示时钟不随十倍战斗加速抽搐；暂停冻结并连续恢复。提供一键关闭动态的对照路径，关闭后战斗结果不变。
9. 同场景、同配置、相同负载测完整忙帧平均值、P95 和尖峰。新增平均开销不超过 0.5ms，P95 增量不超过 1ms。实际本机 GPU 画面测量必须和无头单元测试明确区分；不能用逻辑 60Hz、云端软件渲染或仅无头通过宣称画面性能达标。若超预算先减少装饰及事件表现，不降逻辑频率、不抽子弹、不放宽标准；无法解决则明确报告阻塞，不能宣称完成。

## 实现索引与当前状态

本分支从已核实的远端 `main` `24f0751d5acd698eeb06d8ec7f0eb02e34a09e94` 独立创建；随后整合了已进入远端 `main` 的启动修复 `d2293ce92733766b51bd1aa4f54bec6ea265fd0f`。未引入其他线程未验收改动，也未合入 `main`。

- `scripts/battlefield.gd`：独立显示时钟和 F8／`SPACE_IDLE_BATTLE_MOTION=0` 对照开关；每舰固定相位、尺寸与阵位限幅；玩家及敌舰显示姿态；入场、炮击、受击和死亡短促表现；可见炮口、光束、弹道、命中、护盾、血条和飘字锚点；逻辑阶段隔离显示偏移。
- `scripts/presented_ship_view.gd`：玩家舰体、固定底座、炮台、护盾、推进器和附属舰共用一份显示根姿态；逻辑步前恢复规范姿态；缓存炮口采样；独立推进器小幅变化。`scripts/hyperspace_drone_visual.gd` 为附属无人机提供可恢复的确定性姿态。
- `scripts/ship_body_baker.gd` 和玩家／敌舰计数器记录装配、烘焙、材质失效、轮廓扫描及包围几何构建；显示运动不会使其失效。
- `test/test_battlefield_motion_consistency.gd`：固定种子，动态关／开，在普通和混合武器场景比较战斗快照、事件、掉落、RNG 和重建计数；另注入暂停与十倍速。

## 验收证据

详细机器环境、命令、数值和截图见 [evidence/README.md](evidence/README.md)。本机 Godot 4.7.2 加载仓库已接受的原生 DLL 后，无头测试结果如下；此项是逻辑一致性证据，不是画面性能证据。

| 场景 | 帧数 | 动态关／开战斗结果 | 重建计数 | 暂停 |
| --- | ---: | --- | --- | --- |
| 基础固定种子 | 180 | 完全一致，含 RNG 与掉落 | 完全一致；舰体／装配／烘焙／材质新增 0 | — |
| 混合武器及跨波 | 600 | 完全一致，含 63 次开火、55 次命中 | 完全一致；动态新增 0 | — |
| 混合武器、暂停及十倍速 | 600 | 完全一致，含 50 次开火、44 次命中 | 完全一致；动态新增 0 | 显示时钟与姿态冻结 |

Windows 本机 RTX 2060／OpenGL Compatibility 模式，旧三敌混合武器夹具的 600 帧成对画面测量为：关闭平均 6.327 ms、P95 8.589 ms、尖峰 30.813 ms；开启平均 6.208 ms、P95 7.747 ms、尖峰 29.396 ms。这些数值只说明旧夹具下的表现。**2026-10-20 验收反馈指出模型更新后该夹具已不足以代表高负载，因此旧数据不能证明平均新增开销 ≤0.5 ms、P95 增量 ≤1 ms；高负载画面性能验收未通过，须重新定义并测量实际忙场景。**原测量包含本机 GPU 呈现帧；测试脚本手动推进 60 Hz 战斗，并不把逻辑 60 Hz 计为画面帧率。旧截图只证明该固定场景单帧的可见炮口与光束位置。

## 运行依赖及剩余验证

测试用 `space_native.gdextension`、`bin/space_native.dll`、`probe_motion.gd`、`galaxy_fixture.json` 均位于本独立检出且未提交；前两者通过仓库现有 `tools/play_main.py --install-native` 从已跟踪、哈希校验的 `tools/player_runtime/space_native.dll` 安装，测试探针与夹具只供测量使用。功能代码没有新增对这些本机残留文件的依赖。正式玩家入口仍是仓库根目录 `玩游戏.cmd` 和 `tools/PLAYER_ENTRY.md`，其 Godot 引擎安装、原生扩展安装与启动验收由启动线程负责。本分支尚未在另一台全新电脑上从零拉取并验证一键启动；因此不能把当前分支测试或推送等同于“任意电脑拉取后直接运行”的合入验收。

图像为单帧证据；目标死亡／切换、跨波、暂停恢复、十倍速的数值和轨迹已用固定场景检查，但尚未对每种边界分别留下逐帧视频。最终 `main` 合入仍需用户批准；本任务不自行合入。

## 2026-10-20 验收反馈与待定位问题

1. 用户在旧候选 `c17b5e304c5a4125ca596ec1f3f6ff9003e7c671` 的画面中看到我方舰体微动，但敌舰舰体原地不动。根因已定位：正式绘制使用 `scripts/retained_enemy_contacts.gd` 的缓存节点，而旧实现只给备用的 `draw_enemy_hull_and_status` 接入运动。现已让缓存舰体、炮台、护盾和不旋转的血条读取同一份显示姿态，敌方可见炮口与命中锚点随之对齐。缓存路径保持开启。300 个显示帧中实际可见的敌舰 `record.root` 横向跨度 8.00 像素、舰体角度跨度 1.04°、炮台横向跨度 7.74 像素；逻辑位置不变，护盾角度和命中锚点误差 0，炮口最大误差 0.63 像素，稳定后舰体与护盾重绘次数 0。见 [实际缓存节点证据](evidence/retained-visible.json) 和 [修复前](evidence/retained-before-300.png)／[修复后](evidence/retained-after-300.png)同场景单帧截图。该缺陷的代码与节点级验收已修复，仍等待用户直接观察画面确认观感。
2. 旧三敌混合武器夹具在模型更新后不再代表高负载。上文及 [evidence/README.md](evidence/README.md) 中约 6 ms 的本机测量仅作历史记录，不能作为第 9 条预算达标证据；需用当前真正的高负载场景重新测完整忙帧平均、P95 和尖峰。先不降逻辑频率、不抽子弹、不放宽预算。

修复后混合武器、跨波、暂停及十倍速的开关对照仍完全一致，舰体／装配／烘焙／材质新增重建为零；旧三敌夹具的性能问题仍未解决。因此本分支仍是待验候选，不合入 `main`。本地 10 秒录屏同样使用旧夹具，不能称为已验收的高负载视频；该 MP4 仅留在用户本地，不在 Git 或 Library 中。

## 2026-10-20 current 15-enemy native GPU acceptance (supersedes earlier performance status)

The old three-enemy fixture is historical only. Current `data/game_data.json` has 318 groups with all 15 slots occupied, the game's maximum. The local native GPU fixture uses 15 mixed current opening enemies, five equipped drones, a Heavy Battleship with eight regular weapon entries, fixed RNG seed 1701, and sustained enemies. No logical shots are thinned. The sample is the complete 1373 x 883 Godot 4.7.2 OpenGL Compatibility frame on a Windows RTX 2060 at real 1x: 240 logic steps of warmup and 240 sampled steps, VSync off, uncapped display, mean game/wall ratio approximately 1.0. The sampled load has about 114 live projectiles on average, 160 at peak, 720 fires and 2553 hits. The on/off screenshots are [off](evidence/real1x-max15-cached-off.png) and [on](evidence/real1x-max15-cached-on.png).

The first ABBA run on commit `9f1426d4` showed paired mean increments of +0.762 and +1.033 ms, exceeding the +0.5 ms budget ([off 1](evidence/real1x-max15-off-1.json), [on 1](evidence/real1x-max15-on-1.json), [on 2](evidence/real1x-max15-on-2.json), [off 2](evidence/real1x-max15-off-2.json)). `scripts/retained_enemy_contacts.gd` now caches each mount's ship-local origin, shift and rotation; display yaw transforms only those retained nodes. It also separates static hull size and packet updates from root translation and yaw. The following five paired runs use that candidate optimization, with identical workload and native GPU configuration. Every raw frame, configuration, workload and 1x ratio is in `evidence/real1x-max15-cached-{off,on}-{1..5}.json`.

| Pair | Off mean / P95 / spike (ms) | On mean / P95 / spike (ms) | On minus off mean / P95 (ms) |
| --- | --- | --- | --- |
| 1 | 9.055 / 13.886 / 42.189 | 9.117 / 12.798 / 38.944 | +0.062 / -1.088 |
| 2 | 9.151 / 13.469 / 39.660 | 9.949 / 14.613 / 48.682 | +0.799 / +1.144 |
| 3 | 8.233 / 11.344 / 39.241 | 8.701 / 11.936 / 38.994 | +0.468 / +0.592 |
| 4 | 8.212 / 11.408 / 36.363 | 8.452 / 11.736 / 36.491 | +0.240 / +0.328 |
| 5 | 8.478 / 12.071 / 40.723 | 8.273 / 11.603 / 36.486 | -0.206 / -0.468 |
| All sampled frames pooled | 8.607 / 12.742 / 42.189 | 8.860 / 12.633 / 48.682 | +0.253 / -0.109 |

The pooled estimate is below both budgets, but pair 2 exceeds both. These runs therefore do **not** establish repeatable acceptance at the strict limit; performance remains an explicit open gate. The maximum observed on spike is 48.682 ms; spikes are reported, not hidden in the mean. This is local GPU evidence, distinct from headless logic tests. The test held 1x game/wall time within about 0.3% each run. The per-run fire/hit totals, enemy positions, RNG state and stress configuration match off/on; the [fixed-seed mixed cross-wave/pause/10x consistency test](evidence/cached-consistency.json) also reports identical complete results and rebuild counters. Its counters are hull/loadout/body attachment/body texture/body material all zero on both sides; 13 enemy hull scans and four envelope builds are identical initial spawn work. The [retained Canvas test](evidence/cached-retained-visible.json) covers 300 visible frames with zero hull/protection rebuilds after settling, zero logical displacement, and 0.621 px maximum visible muzzle error.

The optimization is a candidate pending final review and performance signoff. Do not merge into `main` until this open gate is resolved or explicitly accepted by the user.

### Predeclared longer-window follow-up protocol

The 4-second samples above are retained unchanged. Pair 2 ran on 2026-10-20 at about 23:21:54 (off) and 23:22:17 (on), local file time. Its frame-time elevation spans multiple quarters of the on sample (10.032, 10.948, 9.350, 9.468 ms quarter means); it is not one isolated spike. The other off baselines range 8.212 to 9.151 ms. A concurrently running startup check is a possible interference source, but there is no retrospective process trace proving it caused pair 2.

Before any further measurement, fix this protocol: same code, seed, 15-enemy/five-drone workload, window and rendering settings; 240 logical steps warmup followed by **1200 logical steps (about 20 seconds)** of complete-frame timing at real 1x. Run four sequential pairs in the order **off, on, on, off, off, on, on, off**, without selecting or replacing outcomes. Validate native owner, foreground focus, 1x game/wall ratio within 3.5%, 15 enemies, identical combat event totals and no competing Godot or import task at the start. Keep every run even if a validation fails, marking it invalid rather than silently dropping it. Report each run and pair plus all-frame pooled mean, P95, maximum, and between-pair spread. The strict performance gate requires both mean increment at most 0.5 ms and P95 increment at most 1 ms; if any valid pair exceeds, report the repeatability problem and continue optimization or declare the specific blocker. These rules were set before the longer-window runs.

### Longer-window result: local GPU performance gate met

All eight predeclared runs completed in order on the unchanged `41f536be` candidate, with no other Godot or import process detected at each start. The preserved raw records are `evidence/real1x-max15-long-{off,on}-{1..4}.json`; the first pair's complete-frame captures are [off](evidence/real1x-max15-long-off.png) and [on](evidence/real1x-max15-long-on.png). Each sample lasted 19.97–19.98 wall seconds for 1200 logic steps, with game/wall ratio 1.001–1.002, foreground focus, native execution, retained rendering, VSync off, uncapped display and no native handoff. Each had 15 live enemies, five equipped drones, 3725 sampled fires, 12671 sampled hits and 40 sampled purchases; on/off sampled combat counts match exactly. Mean live projectiles were about 113, peak 160; the on-side example averaged 729 draw calls and 77,403 primitives per displayed frame. The code and load were not changed within the sequence.

| Pair | Off mean / P95 / peak (ms) | On mean / P95 / peak (ms) | On minus off mean / P95 (ms) |
| --- | --- | --- | --- |
| 1 | 7.943 / 10.994 / 39.231 | 8.169 / 11.285 / 38.888 | +0.225 / +0.291 |
| 2 | 7.922 / 10.980 / 40.326 | 8.202 / 11.426 / 46.190 | +0.280 / +0.446 |
| 3 | 7.899 / 11.029 / 38.186 | 8.201 / 11.357 / 38.585 | +0.302 / +0.328 |
| 4 | 7.962 / 11.025 / 38.353 | 8.241 / 11.370 / 48.043 | +0.280 / +0.345 |
| All sampled frames pooled | 7.931 / 11.006 / 40.326 | 8.203 / 11.363 / 48.043 | +0.272 / +0.357 |

Every pair and the pooled result are below the +0.5 ms mean and +1 ms P95 limits. Between-pair mean increments ranged +0.225 to +0.302 ms; P95 increments ranged +0.291 to +0.446 ms. A descriptive 95% t interval across four pair means is about +0.219 to +0.324 ms; with only four pairs this describes observed variability, not a guarantee for every machine or workload. The on-side peak reached 48.043 ms, which is reported separately and is not a budgeted percentile. The off baseline was much steadier than in the earlier 4-second series (7.899–7.962 ms), but the data cannot prove which background activity caused the earlier drift. In pair 3, post-sample fixed-wall-time GPU diagnostics accumulated ten more fires and two more hits on one side; this occurred **after** the timed 1200 steps. Sampled event totals, seed/state and fixed-seed headless consistency remained equal. The longer-window result resolves the local GPU performance gate for this fixed maximum-slot scene. Other visual acceptance and current-main integration remain separately tracked below.
