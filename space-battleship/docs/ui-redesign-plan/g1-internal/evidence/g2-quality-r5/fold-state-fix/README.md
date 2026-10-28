# R5两小尾项：折叠保持与记录范围

最小源码 `87ac154bbf553a39e75b224eb275e8b4496b6410`；基线 `a0705baaf55ba7cced11307cfc0ac2d632384dc4`。R5五个结构目标已获根线程具名关闭，两尾项在本候选修订，不据此宣布最终整体通过。[manifest/源字节与图hash](manifest.json)、[同一当前流程16步动作/状态](operations.json)。拍摄HEAD与固定source分列并按已记录源字节核对Git对象；未独立复测。

切换仅选择effect，不再每次强制加入enhanceOpen；现有render记录各效果展开/折叠。A/B均从熟练折叠→连发展开→返回熟练仍折叠→返回连发仍展开→连发折叠→切critical→返回连发仍折叠。等级、顺序、分支与几何不变，pageerror空；1440×900/DPR1原像素。

|同流程状态|A|B|
|---|---|---|
|熟练返回仍折叠|[原像素](scene-proficiency-still-collapsed.png)|[原像素](work-proficiency-still-collapsed.png)|
|连发返回仍展开|[原像素](scene-repeat-still-expanded.png)|[原像素](work-repeat-still-expanded.png)|
|连发返回仍折叠|[原像素](scene-repeat-still-collapsed.png)|[原像素](work-repeat-still-collapsed.png)|

原[R5 operations](../operations.json)第25/56步before/after route均为enhancement，仅记录切critical effect；现保留original_action_label并更正action/scope，不能证明已进入锁定节点路由。本修未补锁定节点交互证据，也不以未记录动作外推通过。原source、PNG及状态不改。

JS语法/diff/hash与同流程保持检查通过；没有新增批次、资产或运行/业务/保存修改，没有运行Godot/游戏。两尾项待根线程最终汇总；完整游戏、A/B选择、整套品质与G2/G4/G9仍开放。
