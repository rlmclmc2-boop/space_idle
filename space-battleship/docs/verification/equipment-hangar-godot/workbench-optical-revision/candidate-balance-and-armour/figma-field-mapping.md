# Figma装备局部：字段映射与实施边界（尚无frame）

用户最新要求精简防御的重复身份/状态、统一武器与防御展示；后明确本次UI调整先经Figma。源码仍 `9e420e1c184d355133737a72f716358203ffa51a`，真实旧证据仍 `ca6914ed3f64eef510c9ca421360a97359ed33f0`。本文与[资产hash表](figma-source-assets.json)只是可独立完成的接入准备，**没有新的Figma设计或Godot实现**。

## 已授权独立frame职责

唯一目标文件 [zlWQqp1rQ4MZoOoMMnerST](https://www.figma.com/design/zlWQqp1rQ4MZoOoMMnerST)，仅在既有page新建独立装备局部editable frame：正式机库/舰体/工作台场景保留，用原生可编辑文本、布局、原正式资产引用和既有公共按钮实例表达武器/防御可比状态。不能将完整实机截图或HTML/SVG整屏烘平当可编辑设计；不能改反应堆2:34/2:49/2:64、公共组件源、其他frame或新建Figma文件。后续通过实际inspect及预览确认编辑结构，并固定真实file/node链接，才能按节点落实Godot；当前没有可供引用的装备nodeId。

## 共同字段与精简口径

| 用途 | Owner真实来源 | 当前UI做法／防御冗余 | 保留与合并边界 |
|---|---|---|---|
| 当前对象 | slot_facts的id/category/equipment_id/paid_level | 侧槽、对象标题、左图标、候选名称/已装备标记多处重复 | 必留当前槽及等级/现装身份；防御无需额外重复身份行 |
| 购级比较 | slot_comparison.current/upgrade.primary，scope=charged_base | 武器显示攻击力，防御显示容量；同一结构 | 必留当前→升级后同口径主值，不用UI反推DPS/成长/容量公式 |
| 费用/购买对象 | quote.count/costs、affordable、payment_reason | 选异候选时左购买依然升级当前槽；例现护盾750→900且65铁，右装甲1000 | 必须明确65铁是现装槽购级费，不是安装价；数量×1→×10→MAX只报价、购买独立 |
| 候选身份/状态 | panel_equipment.id/name/enabled，当前equipment_id | 防御144px两大卡；UI自生成已装备/待安装，后者不是Owner待办队列 | 保候选类型及选中/已装识别；可合并/去掉重复“待安装”，不要伪装已提交 |
| 替换比较 | current.primary、candidate.primary、equipment_id | 武器表头另给真实周期；防御表头又重复现装·护盾/所选·装甲；当前主值左右重复 | 必留清楚现装与候选容量关系；Figma可复用共同现装基线或简化角色表头，不能删掉必要比较或重复完整名称填空 |
| 替换动作 | switch_admission.ok/reason，equip_slot | 安装键又写所选名称 | 必留明确安装目标及准入；与候选身份合理合并，不能删可达替换 |
| 冷却 | cooldown_remaining、switch_admission EquipmentSwitchLocked | 顶部秒数、按钮“换装冷却中”、tooltip原因重复 | 保一次明确剩余秒数/原因及原生禁用语义，减少复述；仍可浏览候选，不自行改Owner规则 |
| 同物 | current equipment_id==candidate_id，NoChange | 隐藏异物比较/安装，购买行贯通 | 保简洁；不要恢复同物重复比较或另造成功反馈 |
| 空槽／未开放 | status=empty；option.enabled；首防御槽FirstDefenceRequired | 未开放控件隐藏，原目录空位保留；真实空槽选非空候选后比较/安装 | 空槽/未开放/休眠不混为一谈；卸下入口是用户明确已移除，非遗漏，不恢复；Owner空槽规则不改 |
| Batch | 当前active slots、paid_level；原Owner购买模式 | 武器/防御同样仅槽号/名称/Lv与数量/执行；无成交明细 | 已非防御额外内容来源；不扩添加说明、回执或第二套模式 |

Owner另给weapon interval_seconds/salvo_count/charge_seconds，shield recovery_rate/recovery_delay_seconds和damage_type。当前UI只显示武器周期，**并未显示护盾恢复率/延迟/damage_type**，不能把它们误列为防御现有待删内容，也不为追平防御给武器加表。数据计算、价格、冷却、开放、提交均留原Owner。

对应代码：equipment_panel.gd `_refresh_comparison`(716)、`_refresh_choices`(839)、`_render_costs`(575)、`_refresh_batch`(940)；systems/equipment.gd `_comparison_value`(181)、`slot_comparison`(218)、`_equip_admission`(620)、`equip_slot`(636)、`quote_slot`(653)；Session仅透传既有公开比较依赖。此映射限定字段语义，不提前另造布局；具体去重排布由真实editable Figma节点承载。

## 实际Figma检查与当前阻塞

已读figma-generate-design、figma-use及其必需index/working-with-design-systems/gotchas。官方create_session成功，sessionId `bea65e24-0ded-49b0-9851-c0a98b0eed24`。成功只读确认：page `0:1`；公共ActionButton `2:29`是COMPONENT_SET，key `2bcb9ce1eecc1c18943144dafd48c69665b8c858`，含normal/hover/pressed/selected/disabled/ready六variant；集合 `VariableCollectionId:2:2`名“舰桥UI”，11个变量、Default模式；可用Noto Sans SC Regular/Medium/Bold。变量的具体名称/值/绑定和按钮各态细节尚未读取，不编造绑定事实。代码库未发现相关Code Connect文件；team-library按equipment workbench/ActionButton搜索为空，现成2:29仍是根明确指定的公共源。

接下来两次只读use_figma（变量名称/类型，及按钮细节/既有绑定）均被官方明确拒绝：

`You've reached the Figma MCP tool call limit on the Starter plan. Upgrade your plan for more tool calls`

返回isError=true，error_code=INVALID_ARGUMENT；额度处理链接 [Figma计划入口](https://www.figma.com/files/team/1697926730519558802/all-projects?upgrade=mcp_rate_limit_paywall)。这是官方计划额度阻塞，非用户设计偏好缺失、非审批拒绝或不确定写入。两调用均只读；截至本记录 **0个创建/修改节点、0次素材上传、0个装备frame**，没有待确认的写入结果。

依根指示已停止所有Figma调用/上传/创建及同能力替代路由，不重试绕过；未直接实施Godot。独立完成本Git字段映射、正式源hash与职责说明；需根处理现成Figma额度后再恢复原项，不能把准备文档当设计交付或总体完成。不新workspace/代理/素材、不pushmain/Library；本SOL未实际上下文压缩。
