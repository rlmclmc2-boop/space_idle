# 品质 R2复查收敛 R5 同版对照

前版 `0aec2d937b06370b5ec4abddf3f5f7a4ea180ae3`；后版 `560a2dcfea9dc46567125e386d499c3e7fc433a8`。[设计/还原/局限](../../g2-quality-r5.md)、[manifest/source-image SHA256](manifest.json)。14对1440×900/DPR1原像素整屏，完整状态与P3变换相等。

|同一状态|A前|A后|B前|B后|
|---|---|---|---|---|
|装配唯一导航|[原像素](before/scene-equipment.png)|[原像素](after/scene-equipment.png)|[原像素](before/work-equipment.png)|[原像素](after/work-equipment.png)|
|路线与启动|[原像素](before/scene-routes.png)|[原像素](after/scene-routes.png)|[原像素](before/work-routes.png)|[原像素](after/work-routes.png)|
|普通形态基础机体|[原像素](before/scene-forge-missile.png)|[原像素](after/scene-forge-missile.png)|[原像素](before/work-forge-missile.png)|[原像素](after/work-forge-missile.png)|
|究极事实与基础图范围|[原像素](before/scene-forge-ultimate.png)|[原像素](after/scene-forge-ultimate.png)|[原像素](before/work-forge-ultimate.png)|[原像素](after/work-forge-ultimate.png)|
|顺序选择与当前完整效果|[原像素](before/scene-enhancement.png)|[原像素](after/scene-enhancement.png)|[原像素](before/work-enhancement.png)|[原像素](after/work-enhancement.png)|
|已保存|[原像素](before/scene-save.png)|[原像素](after/scene-save.png)|[原像素](before/work-save.png)|[原像素](after/work-save.png)|
|写入中|[原像素](before/scene-writing.png)|[原像素](after/scene-writing.png)|[原像素](before/work-writing.png)|[原像素](after/work-writing.png)|

[62步动作/前后状态与22张过程图](operations.json)。[capture-source](capture-source.json)保留拍摄真实HEAD与工作树源文件hash，固定源码后逐文件核对Git对象再绑定source/base；不再用拍摄HEAD冒充后版源身份。制作方记录非独立审运行。

[唯一装备导航](operations/work-equipment-one-navigation.png)、[提前的开始动作](operations/work-route-actions-reached.png) → [实际进行中](operations/work-route-current-running.png)；[究极事实与未覆盖范围](operations/work-forge-ultimate-scope.png) → [改造审阅/取消](operations/work-forge-current-review.png)；[当前防御效果](operations/work-enhancement-selected-defence.png) → [前移与当前新顺位](operations/work-enhancement-order-selected-result.png) → [节点草稿审阅](operations/work-enhancement-branch-review.png) → [原owner分支接纳](operations/work-enhancement-actual-branch.png)；[写入中](operations/work-save-writing-state.png)、[失败恢复](operations/work-save-failed-state.png)。

四家族GLB/派生图source hash沿既有drone-sources，未新增资产；基础机体并未覆盖饰件/究极结构/toon/canonical。JS语法/diff空白、横界/R/T和源图hash通过，pageerror空；未运行Godot/游戏，不重开已闭合有限响应/ready/批量反例。R2/R3/R4/R5与整体品质仍待统一审查，A/B/G2/G4/G9/P3参数和真实持续提供者/native/文件/离线等开放。
