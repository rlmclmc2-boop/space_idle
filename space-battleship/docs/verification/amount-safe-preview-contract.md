# Amount安全预览契约：固定来源与待审边界

纯文档候选，分支`docs/amount-safe-preview-contract`；基底`372f8499b12b4efe88df22acff0554b147a3da38`。本次仅新增[14第9节](../game-design/14-ui-contracts.md#9-待审提案反应炉整组草稿与科研预算的amount安全预览)及入口；没有预览实现、游戏/配置变更或main发布。

## 请求与实际行为核对

- 请求固定：[83d6b47的R1表](https://github.com/rlmclmc2-boop/space_idle/blob/83d6b47ffe39e74a5d3307c222fde1651304b377/space-battleship/docs/ui-redesign-plan/g1-internal/g2-revision-r1.md)。其比例基准是总手动容量/近期收入；确认一次不等于逐命令原子事务。R1的“无需新批量命令”在本候选只作为可行实现路径，不提升为用户禁止必要模块入口的限制。
- 最新前端还原资料固定：[5e287356的godot-restoration](https://github.com/rlmclmc2-boop/space_idle/blob/5e2873567c31eaa744c520485afaf605011303cd/space-battleship/docs/ui-redesign-plan/g1-internal/godot-restoration.md)，已读取R2单预算工作点及连续草稿同步补丁。两个模式分别记忆比例，本次精确金额与持续样本目标不互相覆盖；模式切换和点击已选模式均无提交副作用。
- 后端固定在`e93c221239a10d377b2ca89dd395ebcfa99c9819`；本任务此前已审候选未改Research/Reactor/Economy，当前基底同此行为。下表是实际源码边界，不把b7bb3de3的未合展示查询当主线已有接口。

| 来源 | 核对结果/拟复用 |
|---|---|
| `reactor.gd` `_capacity/_allocate/_distribute/_evaluate` | C先floor；单设备先保留其他已开放设备后钳到余额；均分配置顺序处理余数；免费充能不占手动容量，最终factor不能从占比分别猜。新整组预览只对脱离所有者的目标求值，不承诺逐命令同时接纳。 |
| `research.gd` `set_investment_text/set_investment` 114–129 | 原解析并floor；铁/铀分别变更/发investment_changed，不是两资源事务。 |
| `research.gd` `set_automatic/automatic_due` 131–145；`refresh_income` 225–278 | ratio仍受minimum_ratio限制；仅改开关/比例、不改当前金额、不重置refresh_elapsed。到期且实际岗位满足时按当次income样本max(1,floor(...))刷新。 |
| `research.gd` `_required_work` 176起、`advance` 298起；`game_session.gd` 488、753、881–896、1225起 | 所需量cache目前在state内；预览不能为读而写入可保存required_work。原推进按余额耗尽精确分段，缺钱仍做基础工作；外部速度因子还含人员/算法，不可只拿岗位bool代替速度。 |
| `economy.gd` `income_rates` 442–475 | investment按game字段，取(now−window,now]内合格已入账actual，含galaxy_yield，除完整窗口；peak是wall、production用production_base，三者不可混用。窗口自然移出样本也会改变收入，不能仅等钱包事件。 |
| `amount_value.hpp` ratio 173–177；`amount_api.hpp` div/to_ratio | ratio在被除数≥除数时直接返回1；不能拿该字段当资金能撑多少秒或研究ETA。普通div的Amount结果才是任意时长候选。 |

## 持续0%差异：只阻断该项现有能力宣称

已直接只读核对`config_excel/game_rules.xlsx`：`game_rules!A19=research_minimum_ratio`、`B19=0.001`，即0.1%=10基点。工作簿SHA256：`CA664A86FA325BB6A4767B5140067C27B32A08793188926AD6607A0614DC6791`。现有编译产物SHA256 `308B8F8089750DB99E0190526F2F1FDE91EE2950C5229567D295860B04D077DE`同值；未重编或改工作簿。

R1/R2把“持续0%至少1”写成现有行为，与当前setter的准入不符：开/关均会先因ratio<0.001拒绝。max(1,...)只是已合法进入周期求值后的下限，不能据它越过setter。候选保留原准入并输出InvalidResearchRatio；即时0%/手动0不受此限制。前端应修正当前可用性表述；若要把持续0%做成合法玩法，需要另获明确规则/配置变更授权，本提案不代选。此差异不阻断其他Amount预览契约的独立复审。

## 实施前的定向检查矩阵（尚未执行）

| 例子/边界 | 应有结果 |
|---|---|
| C=101，三项基点3333/3333/3334 | 比例目标33/33/33，剩2；不能擅把余数填满。equal按原规则为34/34/33，两种动作有别。 |
| 基点合计>10000、锁定/未知/漏项、目标Amount总和>C | 拒绝并保留草稿，不钳制/归一化。C=0、0%、任意大C不出现NaN或浮点金额。 |
| 当前武器45/防御35/熔炼20，目标60/35/5；提高武器被拒 | 先熔炼接纳5，再尝试武器；失败后实际45/35/5、剩15，保留武器目标60，重试不重放熔炼。均分只调用一次distribute。 |
| 收入10.9/3.2每游戏秒，3700bp，本次比例 | 目标4/1，净结余6.9/2.2；余额100/20时，断流且无其他支出的库存独撑25/20游戏秒。速率/时长Amount不经float。 |
| 当前样本无收入；本次0bp、合法持续10bp、持续0bp | 本次0/0；合法持续周期样本1/1；持续0不可提交。关闭自动沿用已接纳合法ratio，不清当前金额或周期相位。 |
| 钱包1e120、投入1e5每游戏秒 | 断流库存时长1e115游戏秒，不是to_ratio所得1秒；率0标not_spending/null，余额0且率>0为0秒。 |
| 钱包不足维持付费到完成、单资源先耗尽、率1 | speed_now只反映此快照；有条件完成估时明确足额资金假设/所需资金及当前覆盖性，不能充当实际ETA；缺钱基础工作继续，率1不伪称必有增速。 |
| 切模式/点已选模式、精确金额编辑后来源变化 | 保留两个本次金额草稿、各模式比例及当前生效值；本次主动滑动才重新生成金额。新来源下按保留金额重取比较，持续只重算样本预计值。 |
| 原刷新相位已过期但无岗位，之后恢复岗位 | 不能显示“开启后还要60秒”的固定倒计时；沿原due事实显示到期等待，原入口下次满足条件再刷新。 |
| 纯读、部分成功、配置/免费量/窗口自然过期/项目等级work变化 | 不支付/推进/prepare/保存；旧比较失效，成功回执优先；无全局revision框架，未变定义/所需量复用。 |

本次仅源码/请求/工作簿静态核对与Markdown链接、diff检查，没有运行新游戏测试或给“速度/估时实现通过”结论。三项只读候选的既有审核范围、其验证限制与main审批暂停保持原报告，不借本分支绕过发布门槛。

## 命令归属待裁定

补充[14第9.5节](../game-design/14-ui-contracts.md#95-待双审权衡整组意图的命令归属)：对比UI维护顺序/部分成功、多次发布与Reactor模块内具名整组候选、单次求值/发布。现有publish_reactor在每次成功后可能调用retreat_if_dead，不能把中间态当纯UI细节；这里记录待验证影响，不声称已发现新运行缺陷。Reactor新入口只复用既有预算/求值/发布边界，不引入通用事务。Research则区分目前逐资源按钮的真实消费者，与若选“一次应用共同金额”时可用的小型模块入口；持续设置仍独立。未选择方案，不先改写旧命令、失败语义或UI。
