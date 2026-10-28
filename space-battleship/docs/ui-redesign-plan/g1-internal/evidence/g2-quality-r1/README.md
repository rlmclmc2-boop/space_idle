# P3品质R1同点对照

前版源码 `660eddd3cbfcd5611b8325d100245fc41b37c6c3`；后版源码 `57ae32c3dd18d59ac19a7c953fe10b2d14b1d766`。前后各18张原像素1440×900整屏，DPR1。每对公共状态和P3变换相等；source/image SHA256、状态、响应来源、布局与滚动在 [manifest](manifest.json)。不是全系统品质通过。

[设计、可迁移规则与Godot还原](../../g2-quality-r1.md)。前版在修改前采集；后版在源码提交后采集，期间未修改源码。Playwright等待document.fonts.ready，以screenshot animations=disabled暂停CSS动画；默认battle clock8/parallax0，场景自然工作状态，未拼接或缩放PNG。

|同一工作点|A前|A后|B前|B后|
|---|---|---|---|---|
|科研当前|[原像素](before/scene-research-current.png)|[原像素](after/scene-research-current.png)|[原像素](before/work-research-current.png)|[原像素](after/work-research-current.png)|
|科研37%未提交|[原像素](before/scene-research-draft.png)|[原像素](after/scene-research-draft.png)|[原像素](before/work-research-draft.png)|[原像素](after/work-research-draft.png)|
|星球施工|[原像素](before/scene-planet-building.png)|[原像素](after/scene-planet-building.png)|[原像素](before/work-planet-building.png)|[原像素](after/work-planet-building.png)|
|ready关联人员|[原像素](before/scene-planet-ready.png)|[原像素](after/scene-planet-ready.png)|[原像素](before/work-planet-ready.png)|[原像素](after/work-planet-ready.png)|
|星系建设|[原像素](before/scene-galaxy-building.png)|[原像素](after/scene-galaxy-building.png)|[原像素](before/work-galaxy-building.png)|[原像素](after/work-galaxy-building.png)|
|星系迷雾|[原像素](before/scene-galaxy-fog.png)|[原像素](after/scene-galaxy-fog.png)|[原像素](before/work-galaxy-fog.png)|[原像素](after/work-galaxy-fog.png)|
|船员实际占用|[原像素](before/scene-crew-current.png)|[原像素](after/scene-crew-current.png)|[原像素](before/work-crew-current.png)|[原像素](after/work-crew-current.png)|
|伤害统计|[原像素](before/scene-statistics.png)|[原像素](after/scene-statistics.png)|[原像素](before/work-statistics.png)|[原像素](after/work-statistics.png)|
|反应炉参照|[原像素](before/scene-reactor-current.png)|[原像素](after/scene-reactor-current.png)|[原像素](before/work-reactor-current.png)|[原像素](after/work-reactor-current.png)|

连续操作后同版补充：

- [scene · research-selected-after-continuous-budget](after/quality-scene-research-selected.png)
- [scene · danger-losses-preserved](after/quality-scene-danger-losses.png)
- [work · research-selected-after-continuous-budget](after/quality-work-research-selected.png)
- [work · danger-losses-preserved](after/quality-work-danger-losses.png)

[连续操作记录](operation-checks.json)；[共享壳及默认面板边界](shell-checks.json)。连续操作不依靠截屏数量推断：科研逐资源接纳/0.1%持续/停止/选择/实际人员、星球关联身份/关闭模态、地图工具/拖动/返回记忆、损失矩阵与R/T均有明确检查。装备/强化/仓库/保存仅检查本批共享壳影响，不重做已闭合业务反例。

剩余：盾/炮台/舰体材质、其余模块内部品质推广，真实提供者持续操作与Godot还原；P3真实参数、A/B选择与G2/G4/G9仍未通过。
