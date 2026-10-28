# 品质推广 R2 同版整屏对照

前版 `e474f9f963c8cba63c346bcfb7a0d2829d19c127`；后版 `2cb2a5f2a74eef872bfe7f92edeb612cedcaf9e7`。1440×900/DPR1原像素整屏，无裁切/拼接/缩放。20对默认工作点完整状态与P3变换相同；ready另有4对相同Planet/Crew状态，修复覆盖的琥珀信号。[设计与Godot还原](../../g2-quality-r2.md)、[manifest / source与image SHA256](manifest.json)。数量不代表全系统通过。

|同一状态|A前|A后|B前|B后|
|---|---|---|---|---|
|装配工作台|[原像素](before/scene-equipment.png)|[原像素](after/scene-equipment.png)|[原像素](before/work-equipment.png)|[原像素](after/work-equipment.png)|
|五舰比较|[原像素](before/scene-hulls.png)|[原像素](after/scene-hulls.png)|[原像素](before/work-hulls.png)|[原像素](after/work-hulls.png)|
|强化顺位|[原像素](before/scene-enhancement.png)|[原像素](after/scene-enhancement.png)|[原像素](before/work-enhancement.png)|[原像素](after/work-enhancement.png)|
|密集仓储|[原像素](before/scene-warehouse.png)|[原像素](after/scene-warehouse.png)|[原像素](before/work-warehouse.png)|[原像素](after/work-warehouse.png)|
|当前路线任务站|[原像素](before/scene-routes.png)|[原像素](after/scene-routes.png)|[原像素](before/work-routes.png)|[原像素](after/work-routes.png)|
|改造对象与操作台|[原像素](before/scene-forge.png)|[原像素](after/scene-forge.png)|[原像素](before/work-forge.png)|[原像素](after/work-forge.png)|
|已保存|[原像素](before/scene-save.png)|[原像素](after/scene-save.png)|[原像素](before/work-save.png)|[原像素](after/work-save.png)|
|失败恢复|[原像素](before/scene-failed.png)|[原像素](after/scene-failed.png)|[原像素](before/work-failed.png)|[原像素](after/work-failed.png)|
|敌情|[原像素](before/scene-intel.png)|[原像素](after/scene-intel.png)|[原像素](before/work-intel.png)|[原像素](after/work-intel.png)|
|手册|[原像素](before/scene-manual.png)|[原像素](after/scene-manual.png)|[原像素](before/work-manual.png)|[原像素](after/work-manual.png)|
|ready选中|[原像素](ready-before/scene-ready-selected.png)|[原像素](operations/scene-ready-selected-amber.png)|[原像素](ready-before/work-ready-selected.png)|[原像素](operations/work-ready-selected-amber.png)|
|ready未选中|[原像素](ready-before/scene-ready-unselected.png)|[原像素](operations/scene-ready-unselected-amber.png)|[原像素](ready-before/work-ready-unselected.png)|[原像素](operations/work-ready-unselected-amber.png)|

[逐步动作/前后对象/实际余额与回执](operations.json)保留72步，完成情境与资金情境均标明有限owner样本来源；42张必要过程与结果图和滚动/路线/响应记录见manifest的operations记录。该记录是制作者证据，不代替根线程独立运行。

- 装备：[单槽实际成交](operations/work-equipment-actual-receipt.png) → [两次成交后的未知候选保持](operations/work-equipment-candidate.png)。
- 强化：[顺位后节点审阅](operations/work-enhancement-review.png) → [接纳分支并购级实际回执](operations/work-enhancement-actual-receipt.png) → [下段效果](operations/work-enhancement-lower.png)。
- 任务：[进行中](operations/work-route-task-running.png) → [固化待领奖励](operations/work-route-reward-ready.png) → [同凭据已领](operations/work-route-reward-claimed.png)。
- 改造：[变化与保护审阅](operations/work-forge-review.png) → 取消 → 重新审阅 → [支付50后实际结果/余额190](operations/work-forge-actual-result.png)。
- 保存：[失败恢复](operations/work-save-failed-recovery-actions.png) → [重试仍排队](operations/work-save-retry-queued.png)；[目录草稿](operations/work-save-directory-draft.png) → [应用目录](operations/work-save-directory-accepted.png)；[导入损失审阅后取消](operations/work-import-risk-review.png)。
- 档案：[敌情选择](operations/work-intel-selected.png)、[主动手册](operations/work-manual-selected.png)、[已读](operations/work-notification-read.png)。

[受影响子路由首尾控件、六保存状态与P3稳定](reachability.json)。pageerror空、JS语法/diff空白通过；没有运行Godot/游戏。前后PNG与source均在manifest核验，不用证据图替代Godot素材。

仍开放：科研常态/预算分层、星系设施发展关联与星球空间关系（R1复查后续）；M1盾/炮台/舰体材质、全设备/长状态/动态材质；真实提供者持续接线、任意组合、native/文件/离线/Godot、P3参数/逐舰来源、无人机canonical/真炮口、AI/长光束/输入/性能。A/B、整套品质与G2/G4/G9均未通过。
