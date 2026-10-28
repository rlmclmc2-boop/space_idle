# 装备机库：Godot 实施候选

## 最新范围：保留舰船主体/整体布局，仅上方先出图

B/C整页替代方向已由用户撤回，不再选/深化。旧5b/d446代码冻结但其舰船主体与整体布局保留为基底；上方只重设计多槽组织/对应/选择反馈，下方仅字体、视觉中心、对齐内边距、按钮规格和费用疏密打磨，不改流程、不因打磨恢复代码。M2已纠正；整体线程负责宿主/导航接入，本组不改main，等标准。当前先ImageGen上方图稿，未实施、不合main，历史局部审核不等于整体通过。

## 当前四图WIP停点（实际压缩）

准确接续入口：[upper-display/README.md](../../ui-redesign-plan/g1-internal/equipment-image-design/upper-display/README.md)。已发起U1/U2各新局Frigate/Heavy四图全部完成并查看，原样归档；明确未完成旧槽残留、U2虚构未来锁槽、厚轨拥挤及漏批量入口等。执行者现已实际上下文压缩，仅收集/归档当前自然项后停止；无仍运行图像任务，不再修图/新批。未运行测试、未改运行代码、未合main；旧WIP/缓存完整保留。以下“未压缩”均为当时历史记录，当前以本段为准。

## 历史：旧布局实施冻结，转整体图稿方向比较

用户已停止沿当前布局继续实施。运行源码5b4f72331038622ce739578fcdf3823a0a0b4716、补图d446d9a2b9674ad530c0ab712d7a51b5bd14ec4f及全部WIP保留；局部分项通过不等于整体视觉通过。本轮仅在现有图稿目录用ImageGen比较不同整体组织，B/C两组主图及工具/成熟度限制见 [directions交付](../../ui-redesign-plan/g1-internal/equipment-image-design/directions/README.md)，A淘汰且全部原版保留；35ec原审后仅补B/C核心结构图供再次成熟度挑战，旧实施继续冻结；要求已更新M2；用户确认前不改运行代码/共享宿主/业务/config、不合main。下文实施状态仅作历史，未恢复制作或运行测试。执行者未实际压缩。

## 2026-10-28 选中徽标避让窄修正（待原审）

最终源码5b的 [同版新局Frigate/Cruiser补图](badge-pass/same-version/README.md)已齐，与6ce既有Heavy图组成大小舰交付；本次只取图/记录，未改代码或重跑整套测试。根审已确认武3/武5窄修可关闭，原独审收尾；未合main，之后等待用户视觉验收，不自行启动新批。

固定源码 **5b4f72331038622ce739578fcdf3823a0a0b4716**；[badge-pass/README.md](badge-pass/README.md)仅对应武3/武5徽标被卡片遮挡的窄修正。根审/独审已确认b935原两项关联阻断改善可关闭，本批不重开布局。真实8槽选择/徽标矩形检查0失败，保留原控件/支承/定位/四项保护证据，不重跑无关回归，未合main；执行者未实际压缩。

## 2026-10-28 选中关联可见性修订（待原双审）

固定源码 **b93597a33cf45d164b46edf38b48928440521ad7**；当前证据入口 [locator-pass/README.md](locator-pass/README.md)。Frigate绕舰侧定位实际中段炮塔；Heavy防3代理就近，以短虚线区别原生武器实体定位；选中框按正式PNG可见轮廓且有同槽号反馈。35条实际记录/0失败、Heavy8卡各1次合并重绘、原四项保护0失败。未改main/业务/config，未合main，不自判视觉通过；7a7d/eb8c证据保留为上一候选。执行者未实际压缩。

## 2026-10-28 用户退回后的装备台打磨候选（待根审与原独审）

固定源码 **7a7d5d3e3a6446745200c0f69a83f16dcf496e6e**；[workbench-pass/README.md](workbench-pass/README.md)为当前实施/证据入口。已补M2现有规范，移除标题贴片/常驻卸下，打磨升级台及安装留白，补实际新局/部分/全装备解锁、大小舰/空槽/休眠及正式挂点核对。真实操作35记录/0失败，四项原保护0失败；不自判视觉通过，未合main。下方318f/9794及90dd限定状态均为用户退回前历史，不能代替本轮审查。原工作区/缓存保留，执行者未实际压缩。

## 2026-10-28 历史限定复核（后被用户视觉退回）

固定源码 **318f5f342e8d44006e530f7f9501b517a3aab359**；[clean-pass/README.md](clean-pass/README.md)为本批唯一交付入口，含同版36张操作图、7张原保护回归图、原始记录/hash与失败调试轨迹。原5012候选被复看指出两项视觉阻断及状态反馈缺口，不能用下方旧通过记录代替本批审查。根线程转交确认：根审与替换后的独审已完成源码318f5f34 / 证据9794f8cd的限定复核，无本轮阻断；范围仅材质融合、长值费用、控件状态及原四项修复保留，不扩大为全V0/V2、Windows/DPI、全舰型或长期性能。真实图已发用户，候选冻结等待用户验收，禁止自行启动新批；原工作区/实现分支，无main、业务或配置扩改，未合main。执行者未实际压缩。

## 2026-10-28 视觉修订历史候选

固定源码 **946f71d9f285540948118db5572fa2976fa2a68d**；同版截图、实际操作、字体栅格、四项原关闭问题定向回归、首跑恢复暂停失败与补测说明统一见 [visual-pass/README.md](visual-pass/README.md)。真实操作14条/0失败，定向回归0失败；这不代替图04视觉与整体通过判断。原目录/实现分支，未合main，未改main/业务/配置/其他模块。接管者 `/root/equipment_visual_replacement` 未实际压缩；下方WIP交接只作历史，当前候选以本段及visual-pass为准。

## 2026-10-28 视觉修订历史WIP交接（已接管）

用户否定上一版视觉后恢复装备专属修订；下方“四项通过/冻结”是历史行为修订结论，不能当作本次视觉通过。执行者 `/root/equipment_image_revision_replacement` **现已实际上下文压缩**，按约定仅核已有进程和截图后交接停止。仍为原工作区、`implement/equipment-hangar-godot`，HEAD `b342b7896dd3796ffea571b22ae186b81f3948bc`；本轮未提交/推送，WIP保留原树，不能当可审成品。

已修改的运行文件仅 `src/ui/equipment_panel.gd`（当前SHA256 `071a352cbe4f4d3cb8f167f99fe3b26f043426531b3b7a25ce0d8c38e169a05d`）。已实际挂载机壳/支承、扩展底台、删除槽数横条、拆分费用资源行、当前/所选两列比较、装备专属400/600数字轴Theme及批量结果主次。没有改 `main.gd`、业务、配置、正式舰体/武器或其他模块。共享宿主必要接入点：**无**；灰色“舰桥面板”仍属宿主，若统一其材质需另行协调。

两张原始ImageGen静态PNG与各自提示词在 `assets/ui/equipment/hangar/`，未烘焙交互或数值：

- `terminal-housing.png`：SHA256 `dc67618adc93258feb98cbb6adfb47a48f4048d17540a2d224e8082b22d748ef`，原工具输出 `/workspace/generated_images/exec-01fb4591-41e0-4de7-b5e1-96ba7f52868f.png`；提示词 `terminal-imagegen-prompt.txt`。
- `support-arm.png`：SHA256 `a6a7e7894f6c7b1c7946c7a65deb1f7f3ce35ee5e4d3b326f62fadbc09531e03`，原工具输出 `/workspace/generated_images/exec-bcde0cd5-48f5-40d9-806c-ac74ad41ed2d.png`；提示词 `support-imagegen-prompt.txt`。

两图均已实际查看，原PNG完整复制，运行使用Atlas区域。引用来源为现有机库台面与已批准图04。它们目前仅WIP资产，不代表用户认可。

已有真实4.7.2运行结果（未为交接重跑）：

- `visual-pass/before/`：旧布局15张原像素图、`operations.json`；已有进程完成 `EQUIPMENT_CAPTURE_COMPLETE failures=0 records=9`。此结果不外推新布局。
- `visual-pass/wip/01-starter.png`、`02-starter-slot-selection.png`、`03-cruiser-cannon-comparison.png`：修后已有真实1440×900原像素预览，现已查看03；03 SHA256 `d8f23d3740b1eea0c4cf8981470391cbfa4393b2058526a65ecfd20acd2a3044`。预览日志 `/tmp/space-idle-runtime472/visual-preview.log` 已输出 `VISUAL_PREVIEW_READY` 并结束；交接核查无仍运行Godot进程，无需杀进程或重复启动。
- `visual-pass/font-probe.json`：数字OpenType键 `2003265652` 的400/600坐标已读回；TextServer基础weight元数据均100，样本文字宽度198/201。不能将坐标配置直接冒称实际600字重已验收，仍需字体像素评价。WIP `font-actual.json`保留当前读回。

明确未完成/未通过：03中“本次费用”标题与左图标叠压；支承偏细、斜接和端点接触仍需整理；机壳厚边、台面/控件融合、字体实重与名称/主值/费用层级仍需视觉审查。新布局MAX多资源/长金额、防御、冷却/拒绝与批量打开关闭/真实结果尚未运行。费用行目前逐键展示，超过3种资源的空间须核实，不能隐藏资源。旧临时操作驱动按批量子节点索引找关闭按钮，已不适合新树，应改为现有 `_batch_close` 引用后再运行。四项既有行为修订未有意改动，但本轮尚无足够回归证明保持，不能宣称通过。

继续运行须由接管者自行决定，不自动重跑：沿 [environment.md](environment.md) 的既有DISPLAY/XDG/native环境，保留现有 `generated/config.json`（本轮未改，不需重新发布）；普通真实入口为该文档Godot命令。已有预览驱动 `/tmp/space-idle-visual-preview.gd`，使用 `SPACE_IDLE_SETTINGS_PATH=/tmp/space-idle-runtime472/settings-visual-preview.json`，其命令为同一Godot加 `--script /tmp/space-idle-visual-preview.gd`，会重写WIP截图，重跑前另设输出目录。完整旧驱动 `/tmp/space-idle-visual-before.gd`、布局编辑脚本 `/tmp/space-idle-visual-ui.py`、批量编辑脚本 `/tmp/space-idle-visual-batch.py`仍在临时目录。环境来源/版本/native链接记录沿原环境文档复用。

现场另有1283个未跟踪 `.import/.uid` 本地导入元数据，系恢复/导入产生，未提交、未清理；交接不得全量add或清树。新图/提示词/证据亦未跟踪。没有审批拒绝或环境阻塞；停点原因是实际压缩及视觉/回归未完成。未合main、未强推。

**当前原独审四项修订入口：[review-fixes/README.md](review-fixes/README.md)**，固定源码94040a18b6616af78fa52c07986331d2e943d4f3，未知回执、运行期依赖、无支付供能刷新与等比拾取四项已由原独审具名定向复核通过，相关原操作回归保持；真实图已交用户，等待用户验收，候选冻结。此结论不覆盖长期性能、全组合/全部姿态、跨平台或整体游戏。本页下方保留首批d2bb实施及原始证据，不把历史截图冒称本次同版。

用户确认图04并授权实施后，在原工作区 `/workspace/space_idle`、项目 `space-battleship` 制作。实现分支 `implement/equipment-hangar-godot`，原设计分支继续固定图稿 `07312fcb9fc8d2d47bce771c9f7886670b8be5c9`。依赖 `09af963cf6f66146e019cecd08353426ab6d6abb` 普通合入，无冲突；其祖先包含装备 `5236e4d2`、`ab6e8873`。没有合 main、强推、新工作区、worktree 或子执行者。

首批历史运行源码为 **d2bb4cb9baf7cbb2033b4afbf7839213fcbf1fa4**，机库基础实现为其前版 `7a4c3cf2`。当前冻结运行源码为94040a18，最新具名结论以首段指向的修订记录为准；下方继续保留首批来源与范围。

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
