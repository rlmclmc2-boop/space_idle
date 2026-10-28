# 装备条件合主线：只读核对与准确拟合范围

**状态：仅拟合提案，没有执行合并，也没有制作/验证main-only实现。** 根端要求先回报；本页和manifest是本次唯一新增文件。当前组合代码/未提交工作未改，没有checkout/cherry-pick/merge/reset/push main，未运行游戏或新复测。

## 根端决定：暂不制作隔离装配

根端已读19ab0cfc并确认：整分支仍含未审模块，装备单独合main还需新的legacy装配适配，不能直接合。用户授权为“有必要可以”，目前没有必须立即单独上线的要求，因此保留现有已审组合，不为提前合并额外制作两套装配。

下述范围留作已完成的静态分析，不是继续实施指令。暂不创建main-only实现/分支、不额外验证或合并；继续既有反应堆/星球新候选的必要交接。后续具备完整可合范围时再按条件授权处理；授权未撤销。

## 远端实况与必要性

`git ls-remote --symref origin HEAD refs/heads/main refs/heads/master`及正常fetch核实：默认分支为`refs/heads/main`，固定`e93c221239a10d377b2ca89dd395ebcfa99c9819`；没有master分支。当前组合源为e6842cf5，主线是其祖先；核对前工作区干净。

main仍为572×960旧宿主，装备是VBox表单，EquipmentPanel构造传7个参数；新装备构造只收Session，并调用主线尚无的equipment_slot_facts/equipment_comparison/comparison_changed及结构化成交回执。**有必要做装备主线隔离候选；仅覆盖界面文件不能启动/正确呈现，整合当前分支也不安全。** 当前分支还含反应堆R4、星球R6和多模块只读/预算候选，不能以用户基本认可装备扩大为整分支许可。

技术上可分离：正式舰体/武器/字体、Battle/共享几何、C++ native和生产Excel在main与当前组合相同。只需8个运行路径和5个机库素材/来源文件，外加相关交接文档；不需要新反应堆或星球文件，不需要配置/存档/native迁移。

## 准确来源：不能当整提交cherry-pick清单

完整commit、路径、Git blob和SHA固定在[manifest.json](manifest.json)。下表来源只授权拟选内容；涉及混合提交必须按文件/方法取，不能整批cherry-pick。

| 拟合部分 | 固定来源 | 必要范围 |
|---|---|---|
| 新装备及已审顶部背景退出 | c84c703f（内部ce70b594，证据f76d328f/ad3ca896，布局限定结论e6842cf5） | equipment_panel.gd整文件；保留原始回执Popup、工作台与四保护，不回退旧实现。 |
| 装备只读事实/比较/成交结果 | 94040a18（包含5236e4d2装备部分） | systems/equipment.gd；新增slot_facts/slot_comparison/MAX报价查询、comparison_changed及原命令结构化回执。不能带5236的Enhancement扩展/探针。 |
| Session装备薄装配 | 94040a18 | 仅新增equipment_slot_facts、_equipment_comparison_dependencies、_notify_equipment_comparison、equipment_comparison四方法；在publish_equipment_refit/_publish_research/publish_reactor/publish_world四处插原通知前后行。静态核实四处去掉通知行后方法体与main完全相同。**不取整个Session文件**，不带科研/强化/超空间预览。 |
| 钱包精确失效通知 | 3d763099 | 仅systems/economy.gd的34行budget_changed合并通知增补；保持既审钱包失效契约，不带该提交的Reactor呈现/预览或探针。 |
| 通用共享壳、静态收起/裁取 | ef409d5c（含c49ea0a7修复） | shared_host.gd原文件，纯Control路由/显示/焦点/快照，无R4/R6模型引用。原Astra三P2及裁取限定结论47a910a0保持。 |
| 战场G共同门禁 | 80e5463f | campaign_view.gd原5行差异，和main的Space/焦点/撤焦门禁一致。 |
| 桌面画布 | 7a4c3cf2 | project.godot只将572×960改为1440×900；战场逻辑仍572×960，已有632×900容器、0.9375投影及原输入映射。 |
| main宿主装配适配 | ef409d5c的已审通用壳逻辑，按main旧模块重新装配 | 保留顶部/钱包/15路由、现有已关闭预览/焦点/快照修复，改EquipmentPanel.new(session)。**必须新做隔离适配提交，不能取该main整文件。** |
| 机库素材与来源 | c84c703f / 7a4c3cf2 | hangar-console.png及原import、README、prompt、sources共5文件。主线已有且同版的舰体/武器/字体不重复取；旧终端/支架实验素材不取。 |

## 排除反应堆/星球返修候选的装配办法

反应堆保留main的ReactorPanel（VBox、原purchase/distribute/allocate等公开端口），星球保留main的PlanetPanel（原5参VBox及视觉脚本）；仅各放入通用壳的独立滚动路由，不移除主线已有功能。main适配删除R4 ReactorScene/Stage的创建/呈现报价接线，以及R6 planet_scene/征服信号/新模型专属接线；不调用主线没有的接口。

严格保留manifest所列main原blob：Reactor/Planet/Research/Enhancement/Crew/Galaxy/Hyperspace领域、旧ReactorPanel/PlanetPanel、planet_visual/rotating_planet等。排除R4素材/工作层、R6设施GLB/贴图/Blender来源、conquest_facts等新依赖、预算/只读演示探针。BattleHUD、native、Excel、保存格式和伤害回执唯一消费者不动。

## 可行性与当前限制

**可行，但目前不存在已制作且可直接合入的main-only commit。** 已审公共壳在三模块组合中的结论可以作为来源，不能自动覆盖“换回main旧Reactor/Planet面板”的新适配差异；Session接口裁剪也需要原审确认依赖范围。5236/3d等端口虽然已在当前候选真实消费，仍非主线事实，不以装备视觉认可替这些代码补主线结论。

建议后续在原工作区、原任务制作两个清楚的隔离提交：①装备必要端口及机库资源；②装备UI＋通用壳/legacy模块适配，并交原Astra核差异与必要接入。不得带当前分支所有祖先，也不得假称本提案已完成组合验证。未来执行前重新核main SHA及工作区；发现未提交工作先保全，不reset/覆盖。当前只回报范围，继续遵守根端“暂不合并”，不向main推送。
