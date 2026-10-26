# 第 5 阶段模块交接契约

玩法权威仍为 `docs/game-design/README.md` 所列文档。本页只记录当前代码端口、状态归属和验证边界，不增添规则。

## 状态所有者

| 模块 | 独占状态 | 对外端口 |
|---|---|---|
| `Hyperspace` | 路线层数与最佳时间、凭据账本、奖励与改造随机流、仓库/溢出、装备 ID、预设、挂设、图鉴、过滤、能源 | `prepare_*` 先校验并返回候选；`accept_*` 只在外部端口成功后接受。查询返回副本。 |
| `Campaign` | 主线位置、驻守及返回目的地、舰型与通关事实 | `hyperspace_return_target`、`enter_hyperspace`、`return_from_hyperspace`；`hyperspace` 状态每固定步推进原生核。 |
| `Crew` | 船员岗位、等级及占用 | `hyperspace_candidate`、`reserve_hyperspace`、`release_hyperspace`。船员等级只从该模块取。 |
| `Equipment` | 已购买的所有装备槽及付费等级 | `drone_weapon_source` 取同类全部保存槽的最高付费等级，生成共享战斗 schema。 |
| `Battle`/native | 生命、防御、弹幕、无人机战中状态与传说战斗动态 | `prepare_player`/`commit_player`、`start_wave`/`advance`；不读超空间仓库或钱包。 |
| `Economy` | 唯一余额及收入 | `payment`/`accept_budget`；超空间不保存材料余额。 |
| `GameSession` | 固定步顺序及跨模块事务 | 校验各准备结果，原生接受后提交装备/无人机/钱包，最后通知界面。 |

## 交接顺序

1. 手动入场：读取 Campaign 返回目的地与通关事实，Hyperspace 准备凭据；结算旧掉落、重置 Battle、Campaign 切状态、接受凭据并开始独立编队。每场成功由 Hyperspace 增加波次，十场后固化奖励；失败与退出返回记录的目的地。
2. 挂机：Crew 校验空闲与等级；Hyperspace 准备任务后才占用船员。凭据在完成边界固化奖励。领奖先检查仓储和 Economy 的 Amount 加法，再接受凭据与余额。`(round_id, run_id)` 在本轮账本中索引，旧任务即使下一任务已开始也能幂等重试。
3. 配装/改造：Hyperspace 准备实体及贡献，Battle/native 先验证整组，随后同一次 `publish_equipment_refit` 接受状态、钱包和通知。预览只用实体随机流的局部副本；相同改造操作 ID 与内容返回最近结果。
4. 重铸候选由 Hyperspace 从现有实体推导，保留槽、星球封存门槛从配置计算；旧轮凭据无效。完整重铸必须按 `03-progression.md` 第 7 节构造并校验一份新的 GameSession，保留旧会话直到新会话完全可用。当前没有可触发的 Session 重铸入口。

## 当前验证与限制

`foundation/tests/_hyperspace_probe.gd` 使用同一 Godot/native 核接纳四条路线各十场以及 5、8、20、220 层的 160 场，覆盖手动返回、固定步推进、单次/自动凭据、旧任务幂等领取、改造预览与重复操作、换装、重铸轮次失效。

五类挂设已分别接入资源、研究速度、反应炉容量、碎片与超空间材料端口；领奖/拆解引起的挂设升级也先计算候选，再和钱包及原生状态一起提交。数值重抽的保底费用以 Amount 计算。界面提供路线、凭据、仓库、收藏、过滤、预设、挂设与基本改造入口。

尚未完成：重铸的完整界面与主线全系统新轮状态协调；极端 Amount 边界与 native 动态无人机行为的专项验证。长期保存/恢复属于第 6 阶段。本分支暂不能视作第 5 阶段验收完成。
