# Balance Lab 长期性能审计

本轮不修改正式配置、战斗公式、策略选择或玩家存档。性能结论必须区分自然成长导致的工作量变化、历史长度导致的额外成本，以及结束报告成本。

## FAST / EXACT（Projectile 第一版）

Lab 的 `simulation_mode` 默认为 `exact`，可选 `fast`；Parameter Sweep 使用同一个选择器，不强制 FAST。JSON 顶层、配置、每轮结果、长表 CSV、扫描 CSV 和性能 JSONL 均记录模式。旧 Baseline 缺模式视为 exact；模式不同时标记条件不同。

EXACT 原有 1/60 秒步长及弹体实现不变。FAST 仍逐步执行同一 BattleGame、AutoPlayer、经济、科研、充能与升级，只将已知普通激光/火炮（含敌方命名变体）的飞行替换为 PendingHit。原 fire 保留 shot 引用到调用方写完暴击与宝石字段；在同一步 tick_projectiles 入队。按出生点到目标距离/弹速计算，向上取整至原固定步，首个移动步计入飞行时间。到期放回原弹体数组，与 fallback 按原 serial 排序，再调用原 tick_projectiles；不复制伤害公式或命中/击杀/AOE 逻辑。

PendingHit 为 LabGame 私有二叉最小堆（到期 tick、serial），入队/取出 O(log P)，每步仅检查堆顶，不扫描全部待命中。生命周期随 runner 的每轮 Game；start 成功、leave、玩家死亡和最终 Boss 死亡清空。普通敌人死亡不取消其已发射的敌弹；普通友弹到期核对目标身份及存活，不重定向；已失去目标的普通弹体只有无伤害的出屏表现，Lab 不保留该表现。正常波次切换后的敌弹仍可命中玩家。当前普通弹的战斗目标坐标固定；去掉飞行后，命中位置仍使用原目标，失去目标后的出屏过程不产生伤害。

导弹（含重定向）、持续光束、未知攻击、非正/非有限弹速、非固定步新发射、场外路径及超长溢出飞行时间保持 EXACT。当前核心没有独立穿透弹分支；未来新增攻击必须先验证目标/穿透/移动语义再加入白名单，不能仅按外观视为普通弹。宝石追加攻击仍经原发射/CD/随机流程；对普通弹的暴击、命中、击杀、范围爆炸、充能全部通过原入口。FAST 不做期望暴击、DPS 结算、经济近似或全局事件调度。

### FAST Accuracy Benchmark

从工作区根执行 `python test/run.py test_balance_fast_accuracy.gd --headless --timeout 3600`。默认 BALANCED、固定 seeds 12345–12354，各自从相同配置的新局跑 600 秒和 3600 秒，EXACT/FAST 顺序交替。`BALANCE_FAST_DURATIONS` 可覆盖秒数列表，`BALANCE_FAST_SEEDS` 可选前 N 个 seeds（1–10），缺省不缩减测试。每轮立即写隔离 `.runtime/accuracy_<seconds>_<seed>_<mode>.json`，包含完整指标、配置指纹、核心指纹、耗时、PendingHit/fallback 数。计时包括原 AutoPlayer、统计及最后报告；未完成数据不估算。

`python test/summarize_balance_fast.py <隔离.runtime目录> test/work/balance-fast-summary.json` 同时生成 JSON 和 Markdown。表为 `Metric | Exact | Fast | Avg Error | Max Error`；相对误差先逐 seed 取绝对值，再算平均和最大，避免正负抵消。最终关卡用绝对关数；武器占比用百分点；收入/支出/余额分资源列，宝石与充能分使用项列。双方未出现的首次死亡/TTK 为 N/A；单方缺失、EXACT=0而FAST非零单列为不可比较，不伪装为0%。JSON 保留各指标最大误差 seed、有效样本量和未成对结果。

`test_balance_fast.gd` 覆盖四武器与所有适用宝石、暴击/RNG、伤害/资源/击杀、目标消失、死亡、离场、敌方遗留弹、导弹重定向、Boss 同步清弹及堆排序；`test_balance_lab_ui.gd` 覆盖默认 EXACT、FAST Sweep 的选择/锁定/报告/控件保留。

性能夹具默认用 EXACT + 原 AutoPlayer 自然推进到21关（上限6游戏小时），保存隔离 `fast-natural-fixture.bin`；也可用 `BALANCE_FIXTURE` 显式指定已有自然成长 `high-stage-fixture.bin`。`python test/run.py test_balance_fast_performance.gd --headless --timeout 1200`。必须匹配正式配置指纹。用原免费换装接口将合法已启用武器槽换为火炮，保留自然等级/宝石/经济，重新进入后期遭遇；夹具生成执行 AutoPlayer，计时段固定构筑不运行 AutoPlayer。原弹速及正弹速扫描倍率 0.25/0.0625 各测 60 秒、交替三对；不改血量、伤害、CD 或正式文件。记录准确均值/峰值（FAST 含待命中），比较核心指纹；不能将正弹速扫描压力夹具当成自然成长结论。汇总命令追加 `--performance <隔离.runtime/fast_performance.json>`，即可输出 `Test | Exact Time | Fast Time | Speedup` 及弹体均值/峰值、核心一致对数；`test_balance_fast_summary.py` 检查误差不抵消、删失值/零分母和不完整配对。

### 本次 FAST 实测（2026-09-22）

当前配置指纹 `1c960f7b7ccb56966b3d80f413f68d6f9bea2057aa6d2a86bd25ee3d63242b88`，BALANCED、seeds 12345–12354，10min/1h 各10对；20对核心指纹均一致。所有列出的伤害/DPS、普通/Boss TTK、首次死亡、死亡数、收入/支出/各资源余额、升级、四武器占比、宝石/充能使用的逐 seed 平均/最大误差均为0，双方未发生的事件不冒充已验证事件。1h 有宝石获得/装备与充能活动，但自然样本宝石合成数为0；四武器适用宝石效果另由组合专项验证。两档最终关卡均10/10对完全一致，无非零误差 outlier。

| Test | Exact Time | Fast Time | Speedup |
|---|---:|---:|---:|
| 10min × 10 seeds（合计） | 60.613s | 50.135s | 1.209× |
| 1h × 10 seeds（合计） | 431.568s | 389.100s | 1.109× |
| 21关固定合法火炮构筑，60s，平均P=7.4/峰值25 | 2.032s | 1.940s | 1.048× |
| 同构筑，正弹速0.25倍，平均P=32.9/峰值63 | 2.216s | 1.911s | 1.160× |
| 同构筑，正弹速0.0625倍，平均P=124.1/峰值169 | 3.549s | 1.946s | 1.824× |

后三行各3次交替配对，耗时取均值；9对核心指纹全部一致。P 使用 EXACT 真实活跃弹体数，包含已经失去目标、只剩出屏表现的弹体；FAST 待命中数量不冒充 EXACT 活跃数量。夹具由 EXACT+原 AutoPlayer 自然运行8427游戏秒到21关生成。慢弹速仅为隔离扫描值。数据表明普通弹体密度越高收益越明显；正常1h的持续激光伤害占比均值47.75%，该攻击保留EXACT，不能指望所有玩法都有高倍收益。

证据：[完整误差/性能表](../../test/work/balance-fast-summary.md)、[机器可读汇总](../../test/work/balance-fast-summary.json)。原始准确度目录 `../../test/work/test_balance_fast_accuracy-xjv27om4/space-battleship/.runtime`，后期性能/自然夹具目录 `../../test/work/test_balance_fast_performance-if1yt9dw/space-battleship/.runtime`。保护文件哈希见 [protected-files](../../test/work/balance-fast-protected-files.json)。本轮仅证明当前配置/策略/种子和上述压力夹具；不将旧100h EXACT对照当作FAST长时证据，不横向比较不同配置的速度。

专项回归：FAST39、Metrics78、Lab42、V2 64、原生UI31、汇总Python3、文案Python6项通过，性能契约failures=0。日志为 `../../test/work/fast-final-*.log`，UI截图目录为 `../../test/work/test_balance_lab_ui-60vdcuzc/space-battleship/.runtime`。

结论：当前10次批量与1h实验可用FAST；Parameter Sweep可用作初筛，候选保留EXACT复核。超过1h的自然FAST精度尚未验证，长时间正式平衡结论仍以EXACT为准。

## 诊断入口

Debug Lab 默认每约 5 秒真实时间向输出目录写一条 `performance_*.jsonl`。记录逻辑步数/吞吐、当前与累计游戏秒、关卡、活跃敌人/弹体/掉落、资源窗口、宝石/延迟攻击、节点/对象/孤立节点、静态内存、统计容器、快照/事件/决策桶、已完成报告/警告及信号连接数。仅保留各容器的采样峰值；日志直接写文件，不在内存保存日志历史。

`balance_performance.gd` 管理采样，runner 每个工作片检查真实时间；无渲染紧循环另每 1024 步检查一次。未到期时只读时钟，不生成记录。特别慢的步会延后采样；`sampled_peaks` 不是逐帧精确峰值。日志附带种子、策略、参数值和配置指纹。暂停恢复重新开始吞吐窗口；结束记录包含报告构建。`performance_diagnostics:false` 可关闭诊断，`performance_directory` 可指定目录。正常游戏不实例化该模块。

## 容器与生命周期检查

| 范围 | 保存内容/边界 | 读取与释放 |
|---|---|---|
| Metrics | damage/income/spending/uses 等为装备、资源、系统有限键；次数、总量、极值、间隔在线累计 | 无每击伤害或交易历史；born 仅当前遭遇，死亡删除、换遭遇/撤退清空 |
| Timeline | 默认 30 秒；按总时长扩大间隔；最多 2000 点，runner 默认 1200 | 每秒只检查是否到采样时间；事件最多 5000，批量全局预算仍为 20000 点/100000 事件 |
| 决策密度 | 原来每 600 秒永久增加桶，长批量不受采样预算约束 | 现在使用每轮采样预算限制桶数；必要时扩大窗口，明确输出 window_seconds/per_window，不能冒充每十分钟 |
| Analyzer | 完整诊断在单轮结束/停止时执行，输入为有界快照 | tick 不分析历史；警告保存在该轮报告，reset 释放 |
| 报告聚合 | 原实现为每个指标保存所有 run 的数值数组，并重复构造 row/扫描快照 | 现在每个指标仅 count/mean/M2/min/max，Welford 总体标准差；每个 run 的 row 只构造一次；只影响结束阶段 |
| 经济 | resource_samples 是 60 秒收益窗口 | Lab 每约 5 游戏秒剪除旧项；炉子查询扫描当前窗口，不扫描全程收入；掉落按原自动收取/过期规则移除 |
| 战斗 | enemies 为当前遭遇；projectiles 为活跃弹体；jewel_repeats 为待触发追加攻击 | 换场/死亡清空、完成/失效过滤；目标引用仅由活跃对象持有；无战斗 Node/Timer/Tween |
| 装备/宝石 | 装备槽由舰船表约束，宝石背包上限 200；防御字典按槽位 | 攻击/受击次数是标量，不保存每次攻击；修复/效果临时集合调用或 tick 退出清空 |
| 配置投影 | 装备/敌武器/解锁 ID 缓存各最多 256；效果名按配置宝石 ID | 每轮独立 Database；新轮释放；测试直接修改源配置时 clear_derived_cache |
| 自动玩家 | 每游戏秒决策；每 10 秒宝石操作 | 没有动作历史或 Timer 注册；每轮 configure 重置随机状态/换装时钟 |
| 面板 | 0.25 秒真实时间刷新状态；脏的当前页才填表 | 模拟步不更新表格/图表；结束时导出；批量仅进度中途更新 |
| 多轮 | 完成的报告按用户要求保留，数量受任务上限限制 | 旧 Game/Metrics/Database 可释放；信号连接为 1；reset 清除报告、队列、日志及计数 |

## 已测热点与修改

扫描原先允许将全局弹速换算、激光/炮弹速或导弹弹速设为 0。在隔离零弹速遭遇中，5/10/15/20 游戏秒的弹体数为 24/49/74/98，吞吐从约 7255 降到 1660 steps/s。弹体既不能抵达目标，也不能飞出场外，战斗无法结束；核心弹体循环还会逐个执行 Array.has，进一步放大增长成本。现在扫描拒绝这几种零弹速配置，复用原 invalid_scan 返回；不人为删除正常弹体或修改战斗结算。光束 para1 是增伤爬升时间，仍允许 0。此缺陷是特定扫描配置的真实无限增长入口，不是 seed12345 默认新局的根因。

科研解锁后，原 `BattleGame.advance_hightech` 在一次结算内反复创建有效研究列表、计算研究速率；速率查询又重复遍历配置解锁表。随着有效研究增加，每步固定开销上升。这是活跃系统增加带来的重复工作，不是历史数组扫描。

Lab 现在仅在同一次同步科研结算内复用有效列表/速率，原算法仍处理点数、升级和两个炉子的精确产出边界。此作用域内唯一事件消费者是 Lab 统计，不修改研究分配；退出清空，不跨 tick 保存动态值。配置解锁 ID 通过每轮私有 Database 缓存；解锁是否已达成仍读取实时 profile。

21 关真实成长状态夹具，四轮交替执行相同 60 游戏秒：原实现约 3.13–3.22 秒，修改后约 2.20–2.45 秒。全部 profile/player/enemies/projectiles/RNG 指纹相同。夹具重新进入战斗，不能代替自然长时模拟。

另外用同一 21 关状态对照空历史与满历史（1200 快照、5000 事件、1200 决策桶），各四次 30 游戏秒：平均约 1325/1325 steps/s，核心状态与伤害指纹一致。该结果只证明当前每步成本不因这些有界历史变长而明显上升，不是 100 小时自然运行成绩。

结束报告还曾再次深拷贝全部已完成 run。1200 快照/5000 事件夹具中，该额外报告保留约 12.43MB；共享已完成且只读的 run 字典后约 0.105MB，序列化内容一致。runner 只共享冻结行，仍复制外层数组；重置不修改行内容。Report.build 的默认公开行为仍保留深拷贝，只有 runner 显式选用共享。此修改降低结束阶段额外内存，不把它当作每步降速根因。

## 验证入口与解释

### 已完成自然长测

同一配置、BALANCED、seed12345、1000x上限、关闭渲染，保持原1/60秒固定步，分别从真实新局运行600/3600/36000/360000游戏秒。没有跳过战斗或用时钟跳跃代替100小时。两组100h均正常退出；以下数值为本机实测，不代表其他硬件的固定速度。

| 游戏时长 | 优化前平均steps/s | 优化后平均steps/s | 优化前首/末窗口 | 优化后首/末窗口 | 优化后END/START |
|---|---:|---:|---:|---:|---:|
| 10min | 5336 | 5615 | 5427 / 5041 | 5751 / 5033 | 87.5% |
| 1h | 4199 | 4862 | 5404 / 1961 | 5801 / 2900 | 50.0% |
| 10h | 1178 | 1619 | 5435 / 1073 | 6093 / 1435 | 23.5% |
| 100h | 1103 | 1502 | 5505 / 1012 | 6141 / 1419 | 23.1% |

100h平均吞吐提升约36.3%，实际计算耗时19589.92→14376.72秒。首尾窗口跨越新局和系统解锁后的不同负载，不能把约77%的首尾差当作历史泄漏。成熟阶段10–20h与90–100h平均吞吐：优化前1125→1093，优化后1544→1506（约2.5%下降）。优化后其余完整10h区间为1410–1589 steps/s，没有随着历史长度持续恶化。第40/42关平均活跃弹体约13.4/20.4个，阶段负载存在差异；固定战斗状态的空/满历史对照见上文。

四个时长的完整core/data指纹均一致。core包含profile、资源、装备、宝石、充能、玩家状态、RNG、关卡、伤害、升级、死亡、收入/支出及系统使用计数。100h两组最终均为46关，core指纹为`6cdf320c0997b11e5e7f23cfb3d1619be69c671ea53a45c601662f27b78363ff`。普通game.gd及正式game_data.json与本轮开始时文件哈希相同。

| 100h采样峰值 | 优化前 | 优化后 |
|---|---:|---:|
| Node / Object / 孤立Node / signal连接 | 1 / 1510 / 0 / 1 | 1 / 1510 / 0 / 1 |
| Timeline / events / 决策桶 | 1198 / 5000 / 600 | 1198 / 5000 / 600 |
| 敌人 / 活跃弹体 / 延迟追加攻击 | 6 / 46 / 4 | 6 / 47 / 4 |
| 宝石库存 / 收益窗口 | 200 / 60 | 200 / 69 |
| damage / income / spending / systems键数 | 4 / 3 / 3 / 12 | 4 / 3 / 3 / 12 |

峰值是低频真实时间采样，不是每步精确峰值；两组采样落点不同，活跃弹体等峰值可以不同而核心结果仍完全相同。两组运行结束前内存均约43MiB。旧诊断快照在报告构建前/后采集最后一条记录，导致原始内存峰值59.4/78.2MiB不能直接横向比较。长测快照包含实际逻辑优化；其后报告共享、扫描校验、诊断字段/真实时间采样入口的改动分别由专项验证覆盖。报告额外保留内存12.43MB→0.105MB为独立同内容对照，不冒充本次100h快照的内存成绩。

100次同种子启动/重置和100轮短batch均检查旧Game/Metrics/Database可释放、信号不叠加。首末10轮吞吐比例分别98.7%/94.9%，最后一轮报告成本单独分离。metrics78、数据库106、Lab42、V2 64项通过；另有性能契约、报告所有权、零弹速及历史负载专项。

结果与日志：

- [四档基准及核心指纹](../../test/work/balance-long-comparison.json)、[十小时区间](../../test/work/balance-long-phases.json)。区间末尾内存可能包含结束报告，吞吐按区间实际步数/真实时间计算。
- [优化前日志](../../test/work/balance-long-before.log)、[优化后日志](../../test/work/balance-long-after.log)。原始JSON/JSONL分别在`test_balance_long_performance-9hz88y4m/space-battleship/.runtime`与`test_balance_long_performance-zc2_5tao/space-battleship/.runtime`，均位于`../../test/work/`。
- [100轮生命周期](../../test/work/balance-long-lifecycle-ownership.log)、[报告内存对照](../../test/work/balance-long-report-memory-clean.log)、[最新诊断契约](../../test/work/balance-long-contract-cadence.log)。

### 剩余边界

真实战斗成本仍随活跃敌人、弹体、装备槽和通用效果增加。原弹体循环的Array.has仍可能在大量活跃弹体时形成O(P²)成本；本轮没有在无实测净收益的情况下重写它。极小正弹速或极端发射配置可以扩大P，零弹速扫描已拒绝。自然基准只覆盖本次BALANCED/seed12345及最高46关，不外推所有策略、50关新增槽位或所有扫描参数。1000x是请求上限，不是实际吞吐保证。

### 本轮文件

- 运行模块：新增`balance_performance.gd`；修改`balance_runner.gd`、`balance_game.gd`、`balance_database.gd`、`balance_timeline.gd`、`balance_report.gd`、`balance_scan.gd`、`balance_panel.gd`，均位于`../scripts/`。正常game.gd、正式数值及自动玩家策略未改。
- 测试：新增`test_balance_long_performance.gd`、`test_balance_lifecycle.gd`、`test_balance_perf_contract.gd`、`test_balance_research_performance.gd`、`test_balance_history_cost.gd`、`test_balance_stationary_projectiles.gd`、`test_balance_report_memory.gd`、`summarize_balance_performance.py`；扩展`test_balance_database.gd`、`test_balance_metrics.gd`、`run.py`。均位于`../../test/`。
- 文档：本页、BALANCE_LAB、ARCHITECTURE、STATUS及`../../test/README.md`。

### 复现命令和专项入口

- `test_balance_long_performance.gd`：默认真实执行 600/3600/36000/360000 秒，seed12345、BALANCED、1000x、固定 1/60 步。通过隔离 runner 的 `--headless --timeout 86400` 运行；`BALANCE_LONG_DURATIONS` 可选时长，单位秒、逗号分隔。`.runtime/long_*.json` 保存核心状态/数据指纹/耗时，`.runtime/performance_*.jsonl` 保存低频诊断。
- `test_balance_performance.gd`：主要函数包容计时，重叠时间不可相加。用于定位，不用于宣称无探针开销的吞吐。
- `test_balance_research_performance.gd`：`BALANCE_FIXTURE` 指向自然高关卡 fixture；`BALANCE_REFERENCE_GAME`/`BALANCE_REFERENCE_DATABASE` 指向隔离保留的修改前脚本，和当前实现交替比较。
- `test_balance_lifecycle.gd`：100 次同种子 start/reset + 一个 100 次短 run 的 batch；WeakRef 检查旧对象释放，核对信号数和首尾吞吐。
- `test_balance_perf_contract.gd`：一年决策桶上界、在线方差、日志开启/关闭/释放；不把该合成容器测试声称为一年战斗基准。
- `test_balance_history_cost.gd`：使用 BALANCE_FIXTURE，交替比较空/满历史的同一战斗状态，计时不包含报告构建。
- `test_balance_stationary_projectiles.gd`：直接构造零弹速隔离配置，展示其增长行为；正式扫描入口应拒绝该配置，不能把这个探针当作正常玩法。
- `test_balance_report_memory.gd`：完整内容指纹相同的报告复制/共享保留内存对照；序列化临时字符串在独立函数中释放后测量。
- `test_balance_metrics.gd`：原战斗组合回归，新增科研分配/配置变化与大数分支、炉子产出边界的原实现对照。

自然新局前段系统少、后段系统多，END/START 不单独证明泄漏。还需对照容器规模及主要系统启用后的吞吐趋势。当前配置下完整 100 小时固定步对照需要数小时真实计算；未完成的时长不得填写估算成绩。

`summarize_balance_performance.py <before/.runtime> <after/.runtime> <output.json>` 只汇总已经写出的完整结果，缺失时长保留 null，不外推。它同时比较数据/核心状态指纹，并保留首尾有效真实时间窗口及采样峰值；首尾窗口包含新局与后期不同工作量。
