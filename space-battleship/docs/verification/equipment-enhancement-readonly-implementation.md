# M2/M5最小读取与成交回执：实现候选

分支`feat/amount-safe-previews`，实现基线`0a3a5eb10fa259e3bf1a20d8480a67fc9bbe56d8`。设计已双审通过，运行候选待实现双审、未合main；正式最小契约见[14§11](../game-design/14-ui-contracts.md#11-实现候选装备比较强化摘要与成交回执)。[历史提案](equipment-enhancement-readonly-contract-proposal.md)保留源核对，不当当前运行验收。

## 改动和所有权

- Equipment提供已接纳slot_facts、charged_base同口径slot_comparison、原MAX薄包装；Session只装配实际世界/AI/反应炉/预算。确定数量quote_slot直接复用；_charged_base仅写脱离slot缓存。换装准入原判断提取共用，顺序与reason不变；switch_admission不承诺最终Higgs/无人机配装许可。
- Equipment单槽与批量捕获每个执行quote，发布后以purchase_receipt给逐槽数量/资源支出、合计和提交状态；批量先成功发布再返回后续failure也保留已成交事实。回执不从通知后的_state或钱包差反推，重入不会改外层quote。普通拒绝不伪报已成交；fault_unknown不给确认支出或回滚承诺。原部分成功策略和费用不变，没有整组预览。
- Enhancement用原_effective_level/_describe/_combat投影六卡静态摘要；branch_details给未选/未开放A/B参数和单位，command_allowed沿原_choose，repeat-B2保存/命令准入保持但功能不启用。purchase_preview复用原最多数量搜索，NoChange为0、首级价独立；购买实际回执捕获执行count/costs。未新增强化MAX、历史动态乘数或未来收益。
- 不搬b7bb缓存/提前发信号。强化采用可见时同步新读，实际bonus/armours由Session每次提供，覆盖accept_output更新；不新增通知框架。原运行quote/效果/选择纯函数逐段与固定Git源码相同，函数级哈希见清单。静态摘要中B2/B3展示分开未强制/强制概率及原native规则的来袭倍率，不改变战斗计算。

## 定向证据

[探针](../../foundation/tests/_equipment_enhancement_readonly_probe.gd)使用现行生产编译配置、FoundationAmount和匹配native DLL，显式装配测试槽/余额/级数/分支；修改前Equipment/Enhancement直接取基线Git原始字节加载，不复制报价算法。另有一次真实Session初始化与普通装备发布路径。

| 检查 | 结果 |
|---|---|
| +1/+10报价与修改前相同；升级比较按实际数量，候选沿当前级，原charged_base对照 | 通过 |
| 空槽/休眠/未知/错误类别、首槽与换装锁；购级不受换装锁新增限制；返回深改不污染槽或pending/缓存 | 通过 |
| 单槽+10不足仍完整10级价；MAX与原命令数量相同，材料错误作边界、0统一NoChange、离散极限、跨进化及极端Amount | 通过 |
| 批量前两槽成功、第三次付款注入后续普通失败：两版本同样一次提交并返回failure；新回执在ok=false下仍给两槽quote/合计 | 通过 |
| 发布普通拒绝不伪报购买，显式fault结果为未知边界；同步重入后外层仍保留原10级quote | 通过；仅模块发布回调装配，不是native故障注入 |
| 未选/未开放A/B参数可读且脱离；六效果完整静态合成、repeat-B2原命令接纳但不生效、暴击B3率区分、记忆A及装甲B3、延期B2/B3 | 通过 |
| 改序使已存A门槛失效但选择保留、摘要重算；改A→B后的概率/连锁同步更新；bonus/装甲经accept_output后新读覆盖 | 通过 |
| 强化最多10实际2级/300、0级与首级100分开、原版本状态/原结果相同；新回执是实际执行成本 | 通过 |
| 旧预览后装备等级变化、强化等级/预算变化，确认重新quote最新状态 | 通过 |
| 实际Session/native装备购买一次接纳；slots_changed监听读取新等级，回执支出匹配执行quote | 通过 |
| 同版本main入口check-only、源码/文档diff检查 | 通过 |

最终两份[原始日志及源码/基线/依赖清单](equipment-enhancement-evidence/manifest.json)退出0，无脚本ERROR/WARNING；两份stdout用精确-text属性保留字节，必须另核Git对象与清单一致。首轮夹具未按原路径初始化强化_values，当前/原版均报错且有测试回调引用未释放；该轮不计通过，已补evaluate→accept_output并断开观察回调。没有为修夹具放宽生产条件。

## 复现与限制

沿foundation/README.md及既有Amount验证工作流的同哈希配置/DLL，设置SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG；将基线`0a3a5eb1`的src/systems/equipment.gd、enhancement.gd原始Git字节放入临时.gd，分别设置SPACE_IDLE_EQUIPMENT_BASELINE/SPACE_IDLE_ENHANCEMENT_BASELINE。Godot4.7.2执行`--headless --path . --script res://foundation/tests/_equipment_enhancement_readonly_probe.gd`；入口检查用`--headless --path . --check-only --script res://src/main.gd`。临时原版/编译产物不提交。

未实现新UI；可见刷新频率/交互连续性、全部五舰/装备/强化分支组合实机、完整批量UI、性能、真实native故障注入及完整游戏验收仍未覆盖。当前战斗值继续Battle.attribute_details，候选比较不预测native历史/临时层；每盾累计充能实值等未提供部分不伪造。未改Excel、玩法参数、原生源码、保存格式或共享几何。main审批仍暂停，原生成元数据不纳入提交。
