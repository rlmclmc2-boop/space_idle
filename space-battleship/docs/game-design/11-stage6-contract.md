# 第 6 阶段收尾与持久化交接

玩法、保存结构和验收范围仍以 [唯一入口](README.md) 可达的 03、05、06、07 章为准。本页记录实现边界与当前进度，不另定玩法数值。

## 状态归属与提交边界

| 所有者 | 长期状态与职责 |
|---|---|
| 各业务模块 | 导出自己的稳定实体和进度；候选恢复时独立校验本领域 ID、数值与不变量，不将可写内部字典交给界面或 SaveFiles。 |
| `Battle`/native | 同步导出历史计数、随机状态和 ID 水位。恢复时先建立新核的完整配置，再安装长期字段，重开一个满防御战场；不跨存档保留当前弹体、敌人、受损防御或事件队列。敌方 actor ID 水位由 Campaign/Hyperspace 自己保存。 |
| `GameSession` | 在完整业务调用或固定步结束后冻结快照，校验跨模块引用与占用；加载、导入和重铸均先建候选会话，只有全部检查通过才交给主场景替换。旧会话在此之前仍可用。 |
| `SaveFiles` | 只处理不可变 JSON 快照与 A/B 文件发布，不读取游戏模块，也不替业务处理离线收入。`configHash` 随封包保存；候选会话验证它与当前配置相同。 |
| `main.gd` | 接受单次成功的会话替换并重接页面/表现，不修补候选状态、不在界面重复发奖。 |

保存 Envelope、Amount 及 int64 编码依 06 章第 5 节。重铸保留/重置矩阵依 03 章第 7 节，按该矩阵构造全新 `GameSession`；`Hyperspace.prepare_reforge` 与 `accept_reforge` 只是候选无人机及轮次局部端口，不能直接当作整局重铸。

## 当前实现与验收状态

| 范围 | 状态 | 证据或缺口 |
|---|---|---|
| 第 5 阶段合入 | 完成 | GitHub `main` 已快进至 `a23c5e2044aca7fbd9a95601c208c37c7e1b9697`。 |
| A/B 保存文件层 | 部分完成 | `SaveFiles` 单 writer、generation/changeNumber、配置哈希、大小界限、有限关闭等待与主/备指针；探针覆盖两次保存、dirty、manifest 失败及备份回退。文件层尚未连接 GameSession 的真实快照。 |
| native 长期字段 | 部分完成 | `persistent_state`/`restore_persistent_state` 提供历史计数、随机状态与核内 ID 水位；Battle 可在新核初始化时注入这些值。原生构建与候选拒绝、往返探针通过。Campaign/Hyperspace actor ID 尚未合入完整 Envelope。 |
| 各模块长期状态、保存/加载候选 | 待完成 | GameSession 尚无整局导出、模块恢复、跨域校验、checkpoint 重开与离线微粒结算。 |
| 显式导入与整局重铸 | 待完成 | 尚无候选替换、预览、旧会话回滚边界及 03 章保留/重置矩阵的整局实现。 |
| 页面和旧入口 | 部分完成 | 第 5 阶段超空间界面已接入；保存/导入/重铸页缺失。旧 `game.gd`、`level_editor`、`fleet_battle_runner`、`balance_sim` 当前树中已不存在，仍需最终引用审查。 |
| 全局验收 | 未验证 | 07 章 S01–S06、H06、U01 及跨阶段 fixture/性能/页面烟测尚未形成完整运行证据。当前探针只覆盖文件层与 native 长期字段。 |

## 本阶段下一步

1. 为模块实现具名快照与候选恢复端口，并用同一 `configHash` 验证配置、Amount、稳定 ID、船员占用和回执引用。
2. 由 `GameSession` 组装 Envelope；保存当前业务步后的快照，恢复经济已付款时间、在线任务及待领物，再按 checkpoint 建新战场。
3. 复用候选会话路径完成显式导入和整局重铸，最后让主场景一次性替换并重接完整页面。
4. 用真实 GameSession/native 运行 07 章 S01–S06、H06、U01，并完成前阶段延期项、旧入口、全局 fixture 与性能核查。第 6 阶段全部通过后才申请合入 `main`。

## 2026-10-26 续接交接（未达到合入门槛）

本次把模块快照、`StateCodec`、`GameSession.save_payload/request_save/load_candidate/import_candidate` 和主场景保存、加载、导入预览接上。候选失败会保留当前会话；战斗 checkpoint 在新 native 核重开波次，Started 手动超空间按中断失败返回主线。离线微粒走当前 Excel 的 offlineMax/rate，按余额容量截断。探针已实跑：文件 A/B 探针、离港与战斗 checkpoint 往返、错误装备 ID 的候选拒绝、显式 Envelope 导入、12 小时微粒上限。此范围只是功能骨架，尚不能据此宣称第 6 阶段完成。

### 完整剩余清单

1. **模块校验**：逐字段校验 Economy 待领掉落/收入样本、Research 进度与需求金额、Planet/Galaxy 进度与拓扑、Hyperspace 无人机/回执/随机流/容量/封存及 Campaign checkpoint；消除仅按容器类型接受的状态。验证 Amount 非法值、未知稳定 ID、重复回执、重复船员占用和跨模块引用的候选拒绝，无脚本异常或旧会话变更。
2. **保存生命周期**：按完整业务方法和固定步记录 changeNumber/dirty，在设置指定的现实时间间隔自动保存；保存已付款待执行时间段及暂停原因/通知；载入后保持已入账与已领取凭据的一次性语义。核查 writer 失败、排队覆盖、关闭超时与登录补偿持久化回执，避免 UI 把内存已替换且落盘失败显示为完全成功。
3. **checkpoint**：覆盖选关、航行、清关等待、驻守、撤退、手动超空间中断、在线 Started/CompletedPending、未领 DropId；实证新核满防御、无旧弹体/延期伤害，历史、随机和 actor ID 水位连续。
4. **导入**：对导入源实行完整 Envelope/schema/hash/大小及备份策略；预览保留/覆盖摘要、拒绝原因和保存失败后的重试提示；实测旧会话回滚边界与离线微粒只发一次。当前界面只有绝对路径文本输入和摘要。
5. **整局重铸**：由 Planet 验证开放且 shipyard built、未 conquered；用同一候选计算生成用户确认预览，按 03 §7 和 04 §7 复制/清零所有领域、保留选中无人机并封存、累计轮次和起点授予集，构造全新 GameSession；仅完整校验后替换并申请保存。现有 Hyperspace.prepare_reforge/accept_reforge 仍只是局部端口。
6. **页面/入口**：完成保存目录选择、载入主备选择、导入文件选择及完整摘要、重铸预览确认、dirty/失败/未读提示、暂停/返回场景与页面重接；审查旧脚本/旧编辑器引用及不再使用的入口。
7. **验收**：07 章 S01–S06、H06、U01 的正式 native/GameSession fixture 与页面烟测；前阶段延期的配置负例、C01–C12/CR01–CR09、GPU/逻辑一致性及性能记录。重建当前 native 并运行 Amount/C++ 检查、Godot check-only 和 diff 检查；现用 DLL/GDExtension 仅为本地测试产物，不入库。全部通过后才请审合 main。
