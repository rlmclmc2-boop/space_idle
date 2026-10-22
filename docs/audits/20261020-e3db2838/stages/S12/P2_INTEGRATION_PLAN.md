# S12/P2 正式接入方案（待父级与现有 astra 同对象审查）

状态：`plan_review`；运行候选 SHA：`N/A`。本提交仅方案，不是运行验收或 S12/A07 关闭。
唯一权威仍为 [IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md)，本方案不另立入口。
任务：接替旧实施线程，先审本方案，通过后才修改运行代码。

## 1. 已核对的基线、授权与环境

- 审计父提交：`3fb8fcae989446825cb530e4688037761fa50bc6`；远端审计分支回读相同。
- 远端 main、本地 `D:/放置` HEAD 均为 `31e79337741bf9860d69fff21dae6be994dacd00`；origin 为 `rlmclmc2-boop/space_idle`。
- [P1 有限双审](P1_EXIT_DUAL_REVIEW.md) 的完整证据为 `163ad3dba4131036446faaa37a6073b513fb3be1`；按 [有限退出契约](P1_EXIT_REVISION.md)、[P0 边界](P0_CONTRACT_P1_GATE.md)、[极端 MAX 政策](P0_P1_EXTREME_MAX_AMENDMENT.md) 接入。P1 Python host 只是模型；Godot 查询原型也不是完整产品链证明。
- 父级本次交接提供的新授权：此前提议更换实施线程、进入 P2，用户答“那换吧”（来源 `Sentinel_17e489539278819187cfacd14ba98a82`，2026-10-22）。因此旧入口的“待用户批准 P2”已由本次直接任务补充；方案双审和最终运行双审仍保留。
- `2a6119564e1cffc07bf0b833c3118b97faf6d728` 未通过，仅逐项提取已证明资产；不 cherry-pick 整套候选。
- 本地工作区只读核对：164 个 tracked 改动、806 个 untracked 项（包括 project.godot、生成导入项）；全部保留。Git 所有权提示通过仅本次命令的 `-c safe.directory=D:/放置` 处理，未改全局配置；无沙箱权限拒绝。
- Godot 路径 `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`，实测版本 `4.7.2.stable.official.ed1daf0bf`；SHA256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`，与 P1 冻结记录一致。Python 3.12 路径可见；DLL `D:/放置/space-battleship/bin/space_native.dll` 存在，构建/源码匹配、GPU 和实际游戏入口尚未验收。
- 已读根/工程 AGENTS、executor decision 路由及相关 .agents/skills（token-opt、doc-compact）。本轮只读 Git 对象及文档，不启动游戏、不读取个人存档。

## 2. 必要消费者及实现边界

按一条纵向资源链串行完成，允许多次提交，但不以局部通过关闭 P2。以下定位均基于 main 的 Git 对象，不取本地修改版。

| 消费者 | 接入与必须保留的行为 |
|---|---|
| game.gd 定价、upgrade_currency、upgrade_slot、upgrade_equipment_batch、upgrade_max | 类型化价格/账本与受控提交；x1/x10 逐级旧规则精确累计，单槽全成或零购；多槽 weapons→defence、索引顺序、失败后继续，bool 为至少一槽成功。 |
| refund_equipment/refund_all_equipment；upgrade_reactor | 整批退款先汇总并全量预检；材料失败零入账。共享铀余额走资源边界，保留 S09/S10 反应炉普通域累计、容量和倍率契约。 |
| ai_tech_tree.gd snapshot/advance | 余额判断、有限不足额转换、小数扣费与微量清零一起适配；保留 remaining > 1e-10 与严格小于清零阈值，覆盖 P1 两个 no-op 反例。 |
| game.collect、galaxy_system.advance；native 掉落返回 | 只转换已经生成的 source amount；入账失败前保留来源。samples、run_resources、record_income、峰值、炉时钟、碎片仍按原源值/顺序处理，禁止余额差反算收入。 |
| native_execution_session prepare_numeric_batch/commit_numeric_batch，compiler/handoff | 从隔离快照按同槽顺序预测；一个聚合描述符仅对应实际成功配置。拒绝、保存失败或晚交接失败不得安装旧描述符、撤销已合法成功槽或继续错误后槽。真实 DLL 验证，不以模型代替。 |
| fresh_profile/load_progress_data/reforge；player_loadout_generator、fleet_battle_runner | profile 替换、深复制、预算与生成结果保持编码；身份/代次变化失效旧计划，原地 edit 和 ABA 同样检测；不 float(max) 补账本预算。 |
| _build_save_data/_compose_save_data、progress_writer、SaveTransfer candidate Game | 普通/备份/portable/导入同一资源专用 schema；失败不修改 live、不覆盖有效恢复材料，材料 int64 高位完整往返。 |
| equipment_tab、main、reactor_panel；balance autoplay/game/metrics/timeline/analyzer/views | UI 观察深快照和缓存失效；显示/分析有限投影标识超域，永不回写交易。timeline 复制结果的下游同步适配；有限原域无退化，完整模拟器扩域不在本阶段。 |

资源公开写入只允许“初始化/合法加载与替换、购买与反应炉扣费、整体退款、科研扣费/既有微量清零、原收入入账”这几类受控入口；实施证据逐一列出准确文件/符号/写点及旁路扫描结果。typed 对象只在瞬态 owner 内，profile/JSON 保留独立规范值；不宣称 GDScript 能强制私有不可变。plan 持有钱包、材料、槽等级、完整配置/解锁及 owner 身份/代次，提交同步重验，事件回调后重验后续槽。

MAX 接入 [六行支持族](P1_PARAM_MAIN_FAMILY.md) 及冻结 256/257 调度规则：普通精确前缀、极端有证书的同报价 U 扣款、材料仍精确。其他配置保留可行的精确路径；尚不支持的组合显式报错、零写入并列为未解决项，不能据此关闭 P2 或暗设等级上限。UI 区分 pending/complete/stale/cancelled/error，查询不会自动购买；点击提交重验同一报价。极端 UI 显示近似数量、实际费用、12%及整数尾差界和旧规则退款差额提示，并可查看完整费用。

兼容提案：资源字段继续接受合法旧数值、m/e、v1；候选 v2/v3 和 P1 v4 仅走资源专用严格解析与无损规范转换，非法形状明确拒绝，不静默归零。非钱包字段不因本次扩大接受域。实施前将各编码实际支持域、超出原型 int64 块位置的合法旧指数样例冻结成表；任何合法旧值无法无损接入即阻断，不把原型表示限制变成游戏限制。自身新增保存格式必须全链重载。

不恢复全局 GrowthNumber v3、cashflow_pending/multiply 业务系统、预览推进交易、炉时钟/start/leave 改造、峰值/碎片扩域、全 native 内核或模拟器数值重写；不改玩法、配置、收入公式、材料域或退款公式。若证明必须超出这些边界，先交具体调用/输入反例，由父级与 astra 调整范围，停在相关接线之前。

## 3. 文件白名单（拟供双审批准）

本轮实际变更仅本文件。获准实施后，运行候选从 main 基线建立独立短期分支/干净目录，不在 D:/放置 切换或清理。下列均以 `space-battleship/scripts/` 为前缀，非要求全部修改：

- 新增窄接口：`currency_integer.gd`、`currency_ledger.gd`、`currency_host.gd`、`currency_storage.gd`、`equipment_price.gd`、`equipment_price_bounds.gd`、`equipment_max_query.gd`：提取价格、稀疏账本、转换、MAX 与 owner；禁止顺带替换全局 N。
- 权威链：`game.gd`、`ai_tech_tree.gd`、`galaxy_system.gd`。
- native 适配：`native_execution_session.gd`、`native_execution_compiler.gd`、`native_execution_handoff.gd`；只接描述符/交接，暂不允许 C++/DLL源码协议变更。
- 保存/复制：`save_transfer.gd`、`progress_writer.gd`、`player_loadout_generator.gd`、`fleet_battle_runner.gd`。
- 显示/分析：`equipment_tab.gd`、`main.gd`、`reactor_panel.gd`、`balance_autoplayer.gd`、`balance_game.gd`、`balance_metrics.gd`、`balance_timeline.gd`、`balance_analyzer.gd`、`balance_views.gd`；仅资源编码适配，不重构算法。

审计白名单：`docs/audits/20261020-e3db2838/stages/S12/P2_*.md`、`P2_*.json` 及 `p2_validation/` 下最小复现/夹具/门禁/摘要与必要原始日志；不包含存档、凭据、缓存。唯一入口由父级维护。新文件依赖或发布清单缺项必须先补充精确路径/理由并经审查，不以此名单授权任意增补；若范围超出一个实施单元，由父级与现有 astra 先拆分，不自行新开线程。

## 4. 实际游戏验收及冻结证据

所有运行在干净候选隔离工程、每进程独立 APPDATA/LOCALAPPDATA/user:// 下使用合成存档；记录实际路径。先证实隔离生效才首启；禁止原目录默认启动或访问个人存档。本次 docs-only 不运行游戏测试。

1. **经济与事件**：真实 Game/Godot 下对照 main 有限域 oracle，覆盖 x1/x10 不足零购、多槽成功/失败/后槽成功、MAX 余款顺序、材料边界、整体退款末项溢出零写入、共享铀、科研 0.5/足额/跨 tick/小数/两类微量 no-op；比较成功槽、bool、事件顺序、源收入/样本/峰值，不只看余额。
2. **查询与重入**：实际装备 UI 展示→确认→扣同一价；256/257、六配置、极端费用界/完整费用查看；持续收入与钱包减量、配置/解锁/等级变化、profile 等值替换、ABA、取消和重复点击。pending/取消/stale/error/零购无 live 写，快照及返回编码 alias 修改无回流。
3. **native 与持久化**：真实匹配 DLL 的聚合批次、交接拒绝、晚失败及保存预检失败；合成旧格式/极端跨指数低位/材料 >2^53 的普通保存、备份选择、portable 导出导入、candidate Game、reforge 与生成器往返；新格式首启后重开，坏候选保留 live/恢复材料。记录 DLL哈希、构建来源/匹配证据；缺证据就是 BLOCKED。
4. **实负载**：计时前冻结源 SHA、输入/存档尺寸、槽数、调度和脚本哈希。保留 exact-256/中指数/远指数/真实活动中取消各10个独立冷进程；同时测真实 UI 每秒请求/重启/失效频率、持续收入+科研+掉落+自动保存、多槽同帧累计与完整 load/save/portable 峰值 RSS、字节数及耗时。每帧查询总工作 <=4 ms、heartbeat <=50 ms、请求至实际停止 <=100 ms；涵盖准备/解码/合并/材料/依赖检查，提交成本单列且受 heartbeat 约束。总完成时间完整报告，不恢复已撤销的总时长门槛，不用单回调最大值替代每帧总量。历史 10,000 块/public FAIL 保留；真实频率/保存压力未测完或有卡顿缺口不得称产品通过。
5. **门禁与对象**：使用 S01 精确错误门禁，退出码0但 SCRIPT/PARSE ERROR、缺完成标记、超时都失败；测试覆盖实际候选字节。运行候选仅必要运行文件，测试工具及审计只留现有审计分支，证据固定 runtime SHA、引擎/DLL/命令、期望/实际、原始日志及 Git blob 索引。

## 5. 当前结果与下一步

方案审查双方均 PENDING；运行代码未修改，游戏/native/保存/负载验收均 NOT_RUN。当前可继续的唯一动作是父级与现有 astra 对本次方案审计 SHA 审查；同意后在本线程实施，失败仍在本线程返工。最终须同一干净运行 SHA + 冻结证据 SHA 双 PASS、未解决项为空，才由父级执行获准的 main 集成与本地入口验收。P2 不自行关闭 S12/P3。

待解决：方案范围及白名单双审；干净隔离候选准备；编码支持域矩阵；DLL 匹配/构建和 GPU 能力核验；全部实际链与实负载证据。没有权限拒绝或执行结果不确定的写动作；不把这些待验收项标 PASS。
