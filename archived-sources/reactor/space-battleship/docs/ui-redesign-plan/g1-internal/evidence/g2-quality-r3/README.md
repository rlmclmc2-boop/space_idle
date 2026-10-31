# 品质R1复查续修 R3 同版对照

前版 `5fee3a6aa9ed988c5d375273e8bfe68636308008`；后版 `0aa504d085aeaaa4ab7352babe9614fccfe0d36a`。[设计与Godot还原](../../g2-quality-r3.md)、[manifest / source与image SHA256](manifest.json)。所有图1440×900/DPR1原像素，14对域状态与P3变换相等。预算开合和路由scroll为明确本地呈现差异，独立记录；两版星系镜头统一为x0/y-55/zoom1.3，前版原默认-168/82/1.75，不隐瞒镜头调整。

|同点状态|A前|A后|B前|B后|
|---|---|---|---|---|
|科研常态|[原像素](before/scene-research-current.png)|[原像素](after/scene-research-current.png)|[原像素](before/work-research-current.png)|[原像素](after/work-research-current.png)|
|37%草稿预算|[原像素](before/scene-research-budget-draft.png)|[原像素](after/scene-research-budget-draft.png)|[原像素](before/work-research-budget-draft.png)|[原像素](after/work-research-budget-draft.png)|
|星系建设|[原像素](before/scene-galaxy-building.png)|[原像素](after/scene-galaxy-building.png)|[原像素](before/work-galaxy-building.png)|[原像素](after/work-galaxy-building.png)|
|星系迷雾|[原像素](before/scene-galaxy-fog.png)|[原像素](after/scene-galaxy-fog.png)|[原像素](before/work-galaxy-fog.png)|[原像素](after/work-galaxy-fog.png)|
|星系完成|[原像素](before/scene-galaxy-complete.png)|[原像素](after/scene-galaxy-complete.png)|[原像素](before/work-galaxy-complete.png)|[原像素](after/work-galaxy-complete.png)|
|星球施工|[原像素](before/scene-planet-building.png)|[原像素](after/scene-planet-building.png)|[原像素](before/work-planet-building.png)|[原像素](after/work-planet-building.png)|
|星球待领|[原像素](before/scene-planet-ready.png)|[原像素](after/scene-planet-ready.png)|[原像素](before/work-planet-ready.png)|[原像素](after/work-planet-ready.png)|

[52步动作前后状态与24张过程图](operations.json)保留实际接纳与情境来源，manifest逐图记录对应步骤/实际读数；[设备/长状态/焦点/比例/工具边界](boundaries.json)。这些是制作方可复跑记录，非独立审运行。

- 科研：[常态](operations/work-research-normal.png) → [37%审阅](operations/work-research-37-review.png) → [逐铁接纳后收起](operations/work-research-iron-accepted-current.png) → [持续0.1%实际策略](operations/work-research-follow-current.png) → 停止/保留37% → [设备选择](operations/work-research-device-selected.png)。
- 星系：[开发邻域](operations/work-galaxy-neighborhood-current.png) → [地图点击/发展台同所选](operations/work-galaxy-selection-linked.png) → [缩放拖动/离页记忆](operations/work-galaxy-view-retained.png) → [迷雾隐藏](operations/work-galaxy-fog-private.png)。
- 星球：[点击设施模型](operations/work-planet-facility-linked.png) → [完整ready/idle人员响应](operations/work-planet-ready.png) → [领取后owned/人员仍idle](operations/work-planet-owned.png)。

pageerror空、横界/R/T/JS语法/diff空白/source-image hash通过。未运行Godot/游戏。仍需整体观感复查，地图2D派生图与底沿遮挡/可平移、星球2D底座、M1盾/炮台/舰体及全动态材质仍未成为最终场景验收。真实提供者持续接线、任意组合/native/文件/离线/Godot、P3参数/逐舰来源、无人机canonical/真炮口、动态AI/长光束/输入/性能、A/B与G2/G4/G9/整套品质开放。
