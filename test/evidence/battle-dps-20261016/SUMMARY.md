# 战斗 DPS 统计、脉冲速度与连锁表现：移交证据（2026-10-16）

## 源码与结论

- 工作分支 `work/battle-dps-native-20261016`，基于远端 `main` 的 `e02501b38bff8069f2b15bd8947c54d1dc215a1a`。
- 工作分支已推送三个独立生产提交：DPS `222d0760f0c3a4cd823727ffbd347e087fa032c5`；脉冲速度 `c2dbeba7`；连锁表现 `3c5bc2a989366213627e0a52dedbb7ec4c24e487`。未合并 main。
- 原生协议仅加 `set_damage_stats_enabled` 和 `take_damage_stats`。统计以敌方实际护盾/生命状态差入账；伤害、随机数、击杀、生命周期与所有者不读取统计账本。关闭后账本清空且不建桶。GDScript 保存最近 8 个战斗秒的 16 个半秒桶，暂停不计时，换波清空；界面半秒刷新，关闭即停。
- DPS 定点：`test_battle_damage_stats.gd` 24/24，图形主场景 `test_battle_damage_stats_ui.gd` 9/9，详见 `TARGETED.md`、`PROTOCOL.md`。连锁修复只给视图带入出生时武器类型并复用脉冲/磁轨/导弹绘制；伤害类型、目标排序、数量、速度、轨迹、命中时刻和持续束固定连线均未改。原生 DLL 编译与 Godot 导入通过。
- Excel `config_excel/equipment.xlsx` 的 `laser.para1` 从 10000 恢复 30，生成 JSON 同步；伤害 350、基础 CD 1.5 不变。最终纯脉冲四轮均为 2792 次开火、6563 次命中、末态 137 枚弹体，`final-laser-3-on.png` 可见青蓝主弹体及连锁表现。

## 图形性能方法

复用 `test/evidence/five-environment-20261015/baseline` 的 mixed、laser、cannon、missile、longLaser 五套高负载夹具与计数器。Windows 同机串行，每套连续 `main / DPS 关闭 / DPS 开启 / main`；240 步预热、480 步采样，逻辑 60Hz、实际 1 倍、FPS 0、VSync 0、GL Compatibility、始终有焦点、cache=true/save=false。两侧资源和 `game_data.json` SHA 一致，使用同一 Godot 4.7.2（SHA `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`）及同一新编 DLL（SHA `046a6d98d522102dce933edb5a69684675b67deaf09f6e7e86ba13d5d9ae08fe`）。main 侧是 `e025` 源码加已批准的同一脉冲数据和连锁表现补丁，仍无 DPS 入口；补丁原文见 `control-chain-visual.patch`。两套工程各导入一次并逐轮复用，未每轮复制全套素材。

原始 `1e100` HP 且无护盾的夹具中，伤害小于 HP 的浮点间距，实际 HP 不变，DPS 统计 0 是正确值。最终夹具保持 HP `1e100`，只加可表示扣减且不会杀敌的护盾：四套为 `1e33`，持续束为 `1e25`，恢复率 0；同一套四模式完全相同。`1e30`、`1e32` HP 先导会让导弹杀敌，及 `1e33` 护盾下持续束扣减不可表示的失败记录均另存历史，不参与最终对照。旧速度 10000 与统一青色连锁的无前缀、`fixed-` 等记录也仅供溯源，不能与最终绝对帧时比较。

最终采用的原始帧、主过程、截图、日志、系统负载与文件 SHA 见 `mixed-repeat-final-*`、`final-laser-*`、`final-cannon-*`、`final-missile-*`、`long-final-longLaser-*` 及各自 receipt；`analysis-final.json` 给出完整统计。首次 `final-mixed-*` 因首尾 main 漂移 10.8% 保留但不采用，连续复测漂移 0.5%。所有采用轮均通过完整帧闭合、焦点、实际 1 倍、原生准入、0 次所有者移交及 15 敌舰存活；每套四轮事件、开火、命中完全一致，开启轮均取得正的实际护盾损失与武器槽/无人机来源行。

| 套件 | 完整帧均值 main / 关 / 开 / main (ms) | 主过程均值 main / 关 / 开 / main (ms) | 首尾 main 漂移 | 开启刷新帧均值 / 峰值 (ms) |
| --- | --- | --- | ---: | ---: |
| mixed | 10.397 / 11.253 / 10.361 / 10.449 | 3.866 / 4.296 / 3.843 / 3.878 | 0.50% | 27.28 / 47.05 |
| laser | 7.203 / 7.347 / 7.242 / 7.065 | 2.962 / 3.063 / 2.968 / 2.904 | 1.94% | 25.40 / 42.09 |
| cannon | 9.207 / 10.102 / 9.372 / 9.307 | 2.737 / 3.095 / 2.784 / 2.761 | 1.08% | 25.36 / 41.98 |
| missile | 8.963 / 9.316 / 9.159 / 8.974 | 3.033 / 3.186 / 3.120 / 3.039 | 0.12% | 28.39 / 44.55 |
| longLaser | 11.751 / 11.709 / 11.844 / 11.670 | 4.026 / 4.011 / 4.081 / 3.997 | 0.70% | 29.02 / 53.95 |

五套首尾 main 均稳定在 0.12–1.94% 漂移内，开启没有呈现持续帧时大幅上升；这些均值不能证明功能会提速。半秒显示刷新帧平均 25–29ms、峰值 42–54ms，存在可见卡顿风险，需父审是否满足性能目标。未用低负载或 headless 代替性能验收。早期磁轨在另一精度夹具中的三轮不稳记录 `analysis-cannon-repeats.json` 只作历史证据。

## 画面与边界

采用的实机截图为 `mixed-repeat-final-mixed-3-on.png`、`final-laser-3-on.png`、`final-cannon-3-on.png`、`final-missile-3-on.png`、`long-final-longLaser-3-on.png`：可见敌舰、装备、脉冲、磁轨、导弹及持续光束，连锁载体沿母武器表现。DPS 窗口位于右侧装备区，左侧战场完整。`main-scene.png` 的伤害行由 UI 定点测试注入，不作实际战斗伤害证据。

本次生产修复没有改连锁数量、全舰目标分散、权限、伤害或战斗结算。源码、原始证据和画面交由父线程审查；未自行合并 main。
