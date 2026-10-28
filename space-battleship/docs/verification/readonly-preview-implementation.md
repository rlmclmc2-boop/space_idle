# 三项只读缺口：实现候选与定向证据

分支`feat/amount-safe-previews`，基线`cd4169ccbb9cf94b58e29ac6583ff682465a9df2`。优先三项方向已双审通过；本次运行候选待实现双审、未合main。契约见[14§10](../game-design/14-ui-contracts.md#10-实现候选超空间只读预览与星球自动设置)，[原清单](frontend-readonly-gap-followup.md)其余行不实施；未改配置、原生源码、保存格式、几何或UI。

## 最小改动

- Hyperspace.routes仅补最高已过层best_time，没有有效记录为null；手动8.4秒记录保留8.4，不被在线10秒下限覆盖。
- Session将开始入口原准入/prepare_idle提成同一准备函数，预览只投影route/level/automatic/duration和自动crew{id,level,luck}（luck为现行总幸运快照）；不返回凭据或随机状态。单次仍RunState→开放→prepare_idle；自动仍RunState→AutoRunning→开放→Crew准入→prepare_idle。仅原开始命令reserve/accept及通知；确认重新取最新所有者状态，无占用模拟器或新账本。
- Hyperspace抽出原set_filter的纯校验；preview_filter_import沿原分享串解析/整数规范化，再校验并返回脱离candidate。import_filter对原串重跑同一路径，再沿set_filter接纳；InvalidFilterShare/InvalidFilter、直接setter严格类型与原条件规则保留。
- Planet.visual_snapshot仅补automatic。现有候选setter的实际变化后status_changed口径保持；关闭自动不清running/elapsed/duration。修正原提案：实际hanging_slots已在warehouse实体公开；目录为四类枚举，minimum_level是数值条件。

## 已执行定向验证

[探针](../../foundation/tests/_readonly_preview_probe.gd)初始化真实Session、当前生产编译配置及匹配FoundationAmount/native DLL；路线历史经原恢复校验装配，人员/幸运/星球工作状态是明确的测试输入，不写个人保存或生产Excel。过滤基线脚本直接取固定修改前Git对象，不复刻解析算法。

| 检查 | 结果 |
|---|---|
| 最高层20秒与较低层8.4秒区分、无记录null、返回可改不污染历史；单次10秒与自动完整游戏时长 | 通过 |
| 组合错误下原优先级：停机、自动已开、未开放、缺/占用船员、未知路线、无最佳、在线待完成 | 通过；预览与实际开始口同序 |
| 重复预览前后完整Hyperspace/Crew保存快照与通知计数相等，涵盖任务/凭据/run_id/RNG/保留 | 通过 |
| 预览后船员变占用，实际开始拒绝；恢复空闲但等级/最佳/幸运变化，开始取最新值且只保留/通知一次 | 通过 |
| 39组原分享串基线对照：格式/前缀/长度/base64/JSON、缺键/多键/类型、五条件/非法ID、all/any、关闭空条件、整数规范化 | 返回、原因、规范candidate、确认后current均与修改前源码一致 |
| 深改candidate不污染所有者；确认改为非法原串仍重验并保留current；直接set_filter的float version仍拒绝 | 通过 |
| Planet未知/锁定空快照、默认设置、无空间站拒绝、成功变化单次通知、重复不通知、快照纯度、关闭不取消本次探索 | 通过 |
| Godot main入口check-only及源码/文档diff空白检查 | 通过 |

[原始最终输出与源码/依赖哈希](readonly-preview-evidence/manifest.json)固定通过字节，两项运行均退出0；原始check-only输出保留结尾空行，不为diff空白检查改写日志字节。前期探针装配曾直接写只读因子及用StringName新增路线键；已改为脱离因子与恢复契约要求的String键，不放宽生产保护，不计失败装配为通过证据。没有完整UI/Godot实操、任务推进/奖励/随机流全生命周期、完整存档或几何验收。

## 复现入口

复用`foundation/README.md`当前工具链及原Amount工作流的匹配DLL/同哈希配置。设置SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG，并将固定基线`cd4169cc:space-battleship/src/systems/hyperspace.gd`的Git原始字节放入临时.gd，设置SPACE_IDLE_READONLY_BASELINE指向它；使用Godot4.7.2 `--headless --path . --script res://foundation/tests/_readonly_preview_probe.gd`。入口检查为`--headless --path . --check-only --script res://src/main.gd`。临时基线不提交，原始日志与清单保留在本目录。main审批仍暂停，原生成元数据保留不提交。

## 证据交付换行修订

独立复查发现`641d46db`首次提交时Git将两份CRLF日志规范化为LF：探针Git对象327字节、check-only对象73字节，而原清单记录本地捕获的330/75字节。本地捕获哈希当时核对通过，不代表首次提交的Git对象字节匹配；本次明确纠正该交付边界。

本次不重跑，仅在证据目录用精确文件名的`.gitattributes -text`保留两份原始捕获字节，重新纳入Git并回读对象；清单原sha256/bytes保持，表示原始stdout与本次Git对象均为330/75字节。历史首次Git对象的LF哈希另记previous_delivery，不把换行规范化后的旧对象称作原始字节；源码canonical_lf_sha256仍只表示源码LF规范化边界。运行实现和通过范围不变。
