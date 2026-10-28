# 装备机库：Godot 实施候选

用户确认图04并授权实施后，在原工作区 `/workspace/space_idle`、项目 `space-battleship` 制作。实现分支 `implement/equipment-hangar-godot`，原设计分支继续固定图稿 `07312fcb9fc8d2d47bce771c9f7886670b8be5c9`。依赖 `09af963cf6f66146e019cecd08353426ab6d6abb` 普通合入，无冲突；其祖先包含装备 `5236e4d2`、`ab6e8873`。没有合 main、强推、新工作区、worktree 或子执行者。

固定运行源码 **d2bb4cb9baf7cbb2033b4afbf7839213fcbf1fa4**；机库基础实现为其前版 `7a4c3cf2`。当前仅供原独审，不自行宣称装备或整套游戏通过。

## 审阅入口

- [最终巡洋舰与换装比较](evidence/15-final-cruiser.png)、[初次直接点击槽位](evidence/02-starter-slot-selection.png)、[同口径比较](evidence/03-cruiser-cannon-comparison.png)。
- [+1与进化材料](evidence/04-single-plus1-material.png)、[+10报价](evidence/05-plus10-quote.png)、[MAX报价](evidence/07-max-quote.png)、[MAX实际成交](evidence/08-single-max.png)。
- [换装冷却](evidence/09-switch-cooldown.png)、[真实10游戏秒到期](evidence/10-switch-ready.png)、[批量部分成交](evidence/12-batch-partial-result.png)、[关闭重开保持](evidence/13-batch-result-retained.png)、[首防御槽选择](evidence/14-defence-selection.png)。
- [逐步状态、实际回执和钱包](evidence/operations.json)、[性能定向诊断](performance.md)、[环境与启动](environment.md)、[源文件/图像hash](manifest.json)。

以上15张均为真实 Godot 根视口原像素1440×900，未裁切、缩放或拼接。初始舰为真实新会话；巡洋舰检查使用明确记录的、经所有者 restore_state 验证的受控存档状态（开放进度100、特定付费等级和钱包），不冒充自然赚取进度或用户存档。实际升级、比较、换装、冷却和批量均使用该真实 Session/Equipment/Economy/native，未使用有限业务fixture、假报价或UI公式。临时验证存档和设置均在 `/tmp/space-idle-runtime472/`，未提交。

## 还原与接线

`src/ui/equipment_panel.gd` 是整个左侧机库工作场景。独立静态背景提供空间与实体控制台材质；舰体保持正式 PNG，四炮台由正式 manifest/PNG 指定身份和锚点；槽标签、领线、状态、比较及按钮均为独立真实Godot呈现。没有将生成图中的舰船/武器缩略图当正式资产，也没有把数值烘焙进图。防御图标沿用既有SVG，没有顺带重制其他模块。

点击槽位直接打开该槽的装备选择。浏览候选保留现装；左台始终明确“现装升级”，右台比较当前与所选的同口径主值/攻击周期，单一安装动作才提交。`+1/+10/MAX`只选择数量，费用、购买按钮连续在同一台面。数量报价、MAX、charged_base比较与准入直接消费 `equipment_comparison`；购买/换装调用既有 `buy_levels/buy_max_levels/equip_slot`。所有费用格式化原Amount，未在UI计算成长、总价或MAX。

“全部装备升级”是独立工作点，数量选择后调用原 `buy_all_levels`。展示实际 `purchase_receipt.purchases/spent`、成交后余额及未成交槽位；没有整组预报价或批量算法。实际回执跨关闭/重开及本地数量切换保持。面板的视觉z层和GUI输入顺序均置前，阻挡底层误点，关闭后恢复正常槽选择。

`src/main.gd`只做必要挂载：根客户区1440×900，左装备实际808×900，右显示表面实际632×900；Battle原逻辑仍572×960，既有表现/拾取输入共同经SubViewportContainer变换。没有改战斗参数、碰撞、炮口或Battle代码。原装备表单去重，其他既有面板仍由“舰桥面板”访问；没有按生成图替换全局导航、右侧战场或重设计其他页面。伤害显示设置访问路径同步保留在被挂载的既有BattleView。

## 实际结果与边界

最终操作检查0失败。19→20级实际花1600铁及10简并物质；随后+10实际花49800铁；MAX实际购买19级，花184万铁及20简并物质。每笔都用原Amount核对钱包减实际spent，并核对付费等级增量等于实际count。候选浏览不安装；换装时10游戏秒锁定，期间所有者返回EquipmentSwitchLocked，实际游戏时间到期后同槽可换。批量受限钱包中仅武器2/3各+1、共2600铁，其余槽等级保持，结果可关闭重开。细节以JSON原Amount与回执为准，图中金额为其真实格式化输出。

基础前版的两轮问题与证据保留：`pilot-*`记录最初冷却验证仅等待1.2秒、尚在离港阶段的脚本错误；`before-modal-input-fix-*`记录仅z层修正仍未阻挡后创建控件截获输入的缺口。本版同时修正GUI顺序并新增关闭/阻挡断言，不用旧版0失败掩盖漏检。原main运行截图 `before-main.png`、`before-equipment.png` 保留旧真实呈现，来源为依赖合入后的 `6f0da7fd`，其前端与原设计分支相同。

仍需原独审评价图04感觉、密度、具体对齐、正式防御图标与机库材质的融合。当前只有单装备场景和上述真实操作范围；不代表全模块视觉、完整持续战斗、长期性能、所有舰型/长金额组合或Windows/DPI验收。精确目标分区已在真实挂载核对，未把图04原1585×992/约58.6%分界当批准参数。

执行者 `/root/equipment_image_revision_replacement`，尚未实际上下文压缩。实现与本地生成元数据分开，未改Excel、业务公式、正式native源码或其他模块UI。
