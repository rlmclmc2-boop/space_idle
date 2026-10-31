# 武器／防御共用呈现的防御冗余精简候选

用户明确防御内容过多需统一／精简，随后取消Figma依赖，授权直接在原Godot组件继续。本轮固定源码 `3916ffbc9e246f07693a633a772536faad982258`，基线 `9e420e1c184d355133737a72f716358203ffa51a`；仅equipment_panel4增5删，不等待Figma节点或额度，不新增另一套状态标准。

## 同版整屏与实际过程

下列8张1440×900完整根viewport与4张原像素局部均已实际view_image，不缩放拼贴。4.7.2/main.tscn/Session/native原自然8阶段取图，固定源码后执行；不是以参数或文案清单代替看图。

| 状态 | 完整整屏 | 必要局部 |
|---|---|---|
| 武器同物、购买可用 | [01](01-weapon-ready.png) | [原像素](01-weapon-ready-local.png) |
| 武器替换、购买/安装可用 | [02](02-weapon-replacement-ready.png) | — |
| 武器升级费不足、安装仍可用 | [03](03-weapon-disabled.png) | [原像素](03-weapon-disabled-local.png) |
| 防御现装护盾、同物购级 | [04](04-shield-current.png) | — |
| 防御选择装甲、安装可用 | [05](05-armour-replacement-ready.png) | [原像素](05-armour-replacement-ready-local.png) |
| 真实GUI安装装甲后 | [06](06-armour-installed.png) | — |
| 再选护盾、原10秒冷却禁用 | [07](07-shield-replacement-cooldown.png) | — |
| 原Batch当前状态 | [08](08-batch.png) | [原像素](08-batch-local.png) |

## 精简了什么，保留了什么

- 比较表头共用“现装／替换后”。防御不再将卡片已有装甲／护盾名称重复写入比较表头；容量750／1000仍同口径并列。武器沿相同角色表头附Owner原周期1.5／2.4秒，不塞恢复率或其它新字段追平。
- 两类候选均移除UI自行生成的“待安装”，保原选中面、候选名称和真正“已装备”标记；选择不等于提交，没有Owner待安装队列。安装键保明确“安装装甲／安装护盾”目标及Owner准入。
- 冷却保顶部剩余秒数和原Native disabled；安装键保持目标名称，不再另写“换装冷却中”。只去EquipmentSwitchLocked重复tooltip，其它Owner拒绝原因仍走原_reason提示，未吞掉其它唯一原因或改准入。
- 费用标题统一“升级费用”。左侧当前槽／等级、当前→升级后、真实费用／数量／购买保留；例如现装护盾750→900、65铁，右侧装甲1000。65铁是当前槽购级费，不是安装价。购买与替换仍原两个独立Owner命令；×1→×10→MAX只报价循环不改。

原材质、台壳/左右几何、舰体主体/泊位、候选卡/比较/按钮同组件状态源保持；不叠节点或增盖片。未锁纯空位无交互、无记录、用户取消的卸下入口继续不恢复。公共宿主及共用状态协调仍整体组负责，本组不写公共源或main。

## 版本与验证边界

[源码边界](source-boundaries.json)核60个其余顶层函数逐字9e；仅_render_costs、_refresh_comparison、_refresh_choices中的上述呈现文本变更。Owner/Session、资源helper图集、机库/面材/防御SVG及其它14项边界文件逐字原版；样式初始化、布局、刷新调度/失效和候选节点缓存原样保留。此次自然钱包变零阶段refreshes/option_reads/candidates_updated增量均0，无每数值全面读候选或重建节点。

[原操作记录](visual-operations.json)与[驱动](capture-driver.gd.txt)保真实数据和文字，环境/日志同版归档。check-only exit0，视觉过程exit0，`EQUIPMENT_SHARED_FIELD_REDUCTION_VISUAL_COMPLETE failures=0 stages=8`。受控开放/武器Lv19/有限钱包/现装护盾Lv1无冷却经既有恢复端口准备；真实GUI点防御槽→装甲→安装得到Owner ok=true，现装标记及native容量1000随之更新；再选护盾为真实10秒冷却锁态。未实际等待到期，不宣称完整冷却流程。

本次无购买、独立交易全链/36、自然成长解锁、全舰全槽、极端MAX、focus/hover/pressed矩阵、Windows-DPI或共享宿主组合新跑。旧证据保各自版本，不外推。本轮12图已实际看，仍交根/原唯一Astra整体判断，不自判防御精简/整体品质或用户接受。

Figma尝试及字段/资产准备仅[历史记录](../candidate-balance-and-armour/figma-field-mapping.md)，用户已取消该依赖；停止所有Figma调用/额度探索，未创建节点/上传。原workspace/art分支/cache/未跟踪/tmp保全，无新任务/代理/工作区/素材批；本SOL未实际上下文压缩。
