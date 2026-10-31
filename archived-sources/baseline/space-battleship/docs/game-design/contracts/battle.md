# 战斗/航程/拾取前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 战斗/航程/拾取：battle_view、battle_hud、campaign_view、economy_view、attributes_panel | Battle `hud_values/statistics/attribute_details/presentation_clock`；Campaign `status_text/progress_facts`；Economy `balance_rows/drop_markers/budget` | 表现绑定/绘制；Campaign `toggle_guard`、Session `set_pause`；Economy `collect_at` 后调用注入的 `refresh_growth`。`consume_damage_receipts`另按第4节单一消费 | Campaign `status_changed/progress_changed`；Economy `display_changed`；native表现按帧读取 | 伤害数字寿命、HUD展开、显示变换和悬停。拾取输入先逆变换到逻辑战场；不改共享命中几何。 |

## 7. 已实现出口：敌盾与双条的最小战场展示契约

**状态：最小只读展示出口已实现；不代表双条画面、G9或全场性能达标。** 实现前设计核对基线为`main@6b8c266556b0b95d8aaa3a97a5a756bd98f653f5`；仅该实现前基线中涉及的运行代码与`317548d7`一致。依据为[只读核对012283f4第6节](https://github.com/rlmclmc2-boop/space_idle/blob/012283f42725aeb8fb316a585489e79284329f95/g0-envelope-and-godot-coordinate-review.md#6-追加可达敌阵的占位归属及三项装配边界)。范围只含敌舰盾状态、双条数值与定位；无人机锚点、敌阵重排、完整装配包络及G9验收分别待定，不混入此提案。

实现版本为`7f77acf6`，dirty合并修订为`f4ccf4ca`。验证记录、适用边界与成本限制见[定向语义证据](../../verification/enemy-presentation/7f77acf6/README.md)及[成本证据](../../verification/enemy-presentation/cost-7f77acf6/README.md)。

### 7.1 实现前基线与已实现出口

| 层 | 实现前基线 | 已实现最小增补 |
| --- | --- | --- |
| native Actor | 持有`generation/uid`、`hp/max_hp/shield/max_shield`及存活事实；战斗推进、受击和恢复仍由核心负责，运行中的generation会因生命周期失效而改变。`enemy_views()`缓存行当前有uid、位置、hp、dead、视觉身份等，未输出完整盾甲值/上限。 | 沿原`enemy_views`内部读取链补展示出生代数及`max_hp/shield/max_shield`，展示出生代数取安装时冻结的generation，保留既有hp/dead；不改Actor生命周期，不新增另一套账本、数值求解器或面向UI的native调用口。 |
| Battle | 已有共享敌轮廓/锚点及`draw_enemy_overlays`；玩家`hud_values`已有盾甲当前/上限/比例。敌情`enemy_intelligence`目前没有最大值，shield缺字段时返回0，不能据它绑定真实盾条。 | 已提供具名只读`enemy_presentation()`，将核心事实与当前共享几何关联成下表行；敌情等既有消费者仍经Battle，若复用新字段由Battle内部适配，不要求本轮重写其页面。 |
| 前端 | BattleView与HUD已有绘制/刷新路径；没有完整敌盾/双条绑定。 | 敌盾/双条数值和定位只从Battle新入口读取；前端拥有外缘美术、条形布局、投影、显隐与过渡，不读`_kernel`、`_enemy_hulls`或存档，不从伤害回执倒推余额。 |

`Battle.enemy_presentation()`返回只读行数组，以下字段均为必要输出，不增设通用响应封套：

| 字段 | 类型/来源 | 消费含义 |
| --- | --- | --- |
| `id` | 不透明String，由Actor安装时冻结的generation与uid派生 | 同一安装实例的稳定展示身份；死亡、撤退后的运行中generation不得覆盖其展示出生代数。数组下标、mon配置ID、槽位和显示名称都不能替代它，前端不解析组成。 |
| `visual_key` | String；复用既有敌舰视觉身份 | 供前端关联该舰的外缘资产/样式，不从数值size或终波序号猜模型，不传native对象或内部句柄。 |
| `origin`、`body_bounds` | Vector2、Rect2；来自同一敌舰当前共享逻辑锚点与舰体轮廓 | 都是战场世界坐标，仅承诺双条与外缘的粗定位。body_bounds只含舰体，矩形不表达贴轮廓形状，也不是炮台/护盾/文字的完整包络，不据此关闭G9；贴轮廓与完整装配外缘需求待前端具体设计后按M1单独定稿，不预先扩展通用接口。 |
| `dead` | bool；核心存活事实的映射 | 前端决定隐藏/退场；不得用单条归零、盾甲相加或贴图状态另判死亡。 |
| `armour`、`max_armour` | String；分别映射核心`hp/max_hp`的Amount规范十进制文本 | 仅展示敌装甲当前值与上限；不是另建装甲状态或改生命规则。 |
| `shield`、`max_shield` | String；核心Amount规范十进制文本 | 区分无盾上限与有盾但暂时耗空；禁止缺字段时用0伪装已接线。 |
| `armour_fraction`、`shield_fraction` | 有限float，范围[0,1]；native使用与Amount `to_ratio`相同的类型化`Amount.ratio`路径，Battle转交缓存 | 仅作绘制比例，不反算金额或回写业务。最大值≤0时比例为0；最大盾>0、当前盾为0仍是耗空盾条，不等于死亡。 |

### 7.2 身份、快照与失效

- 身份稳定性限于当前Battle绑定生命周期。主线和异空间各自分配uid，不能只靠uid跨编队复用前端节点；安装时将当时的generation与uid冻结为该展示实例的出生身份，再由Battle形成id。后续死亡、撤退引起的Actor.generation递增只沿用既有生命周期语义，不改写展示出生代数，避免同一实例在退场时换id。换波重新安装形成新身份；会话替换/恢复或Battle重建时，装配处重新绑定并清空旧视图缓存，不要求恢复前后展示id连续。不把展示id写入存档，也不改变既有Actor、Encounter/Attack身份或保存水位。
- 同一次读取的数值、dead与几何必须来自一次已完成推进/接纳后的状态。换波、清场、撤退、恢复及共享几何更新后使对应展示缓存失效；行从完整快照消失或dead为真时，前端清除旧锚点/交互，过渡只保留其本地副本，不再绑定旧对象。
- native沿既有`actor_view_changes`更新：安装标记初始展示字段并写入上限；当前值/上限、受击仅耗盾、盾恢复及dead变化都必须使对应行失效并更新，不能只等hp变化。同一读取间隔内的命中/恢复仅向既有dirty集合合并盾甲字段位，在`enemy_views()`重建只读快照时从最终已接纳的类型化值投影一次；dead单独变化不重算盾甲文本或比例。恢复继续在现有战斗推进处结算，查询不得调用advance或恢复结算。
- Amount规范文本只在对应当前值或上限事实变化时生成；每条比例只在其当前值或上限变化时经Amount计算。安装后的首次快照生成初始展示值，未变化的上限文本与几何继续复用；几何仅在对应共享几何事实实际变化或重新安装时更新。当前盾变化不得触发静态上限与几何重算，显示帧和UI尺寸变化也不触发这些重算。
- BattleView在可见显示帧合并读取一次即可；不加全模块广播、每弹事件通知或UI业务轮询器。native可按失效事实重建只读显示缓存，多次读取只复用或装配该缓存，不消费领域结果或伤害事件，不按显示帧重新生成Amount文本、比例、静态上限或几何。隐藏视图不停止Session推进；重新显示读取最新完整快照。

### 7.3 隔离、Amount与绑定边界

原始Amount保留核心语义，以规范文本越过展示边界；不得`float(armour)`后除上限，或由条长重建数值。比例在native只读行缓存重建时直接使用已接纳Amount值的`ratio`（与`FoundationAmount.to_ratio`同一路线），按第7.2节的dirty字段变化合并生成，Battle仅映射缓存；死亡后的实际文本不因绘制比例钳制而被改写，前端按dead处理退场。现有`_hud_fraction`把解析或比例计算失败回退为0的吞错分支只是当前实现事实，不是本契约允许把失败解释为合法空盾的语义，也不承诺原样复用整个函数。

只读展示查询只映射已接纳事实与展示缓存，不新增`RunState.fail`、初始化/接纳或重复领域校验职责，不在查询中重新验证Amount、几何或生命周期。事实有效性及原有故障处理继续归既有初始化、命令/接纳和战斗推进入口；不得为弥补`_hud_fraction`吞错而在读取路径另建校验或停机链。缺字段或比例计算失败不构成合法空盾，具体实现须保持这一语义且不扩大查询职责；本契约不改现有故障政策。

玩家继续使用`hud_values`，敌舰使用上述具名入口；Battle是前端接触战斗所有者的边界，native仅供Battle内部读取。现有绘制、统计、敌情端口不因“唯一边界”改成一个全能模型。`consume_damage_receipts`仍由BattleView单一消费，新查询不能drain事件；读接口不支付、不保存、不改时钟/随机/目标。

盾外缘形状、完整包络、双条偏移/间距/字号归前端资源与布局；`origin/body_bounds`只提供双条/外缘的世界粗定位，不传窗口像素或固定UI安装框，也不承诺仅靠矩形实现贴轮廓。若具体前端设计需要贴轮廓数据，先明确该设计的最小缺口再另行评审，不在本契约提前增加通用轮廓或包络接口。前端使用统一的世界到界面映射，只投影一次。无人机真实炮口、敌阵坐标或任何共享碰撞几何变更，须分别提案，不能随本接口落实。
