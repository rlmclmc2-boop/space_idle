# 战场材质 R4 原像素同点对照

前版 `449fd843d4b21cbdf9d1c5f186ffa9e172e06532`；后版 `90d9f3a25516baf67d9508f0d8bf2d86a3c8d63f`。[设计/材质配方/Godot还原/局限](../../g2-quality-r4.md)、[manifest/source-image SHA256](manifest.json)。14对1440×900/DPR1原像素整屏，完整BattleDesign状态、全部stats几何/炮口/投影与装备域相等；[checks](checks.json)另核左侧808px逐像素相等。此为代表素材层检查，不是G9。

|同一状态|A前|A后|B前|B后|
|---|---|---|---|---|
|当前巡洋舰|[原像素](before/scene-current.png)|[原像素](after/scene-current.png)|[原像素](before/work-current.png)|[原像素](after/work-current.png)|
|五普通家族|[原像素](before/scene-families.png)|[原像素](after/scene-families.png)|[原像素](before/work-families.png)|[原像素](after/work-families.png)|
|精英/首领|[原像素](before/scene-ranked.png)|[原像素](after/scene-ranked.png)|[原像素](before/work-ranked.png)|[原像素](after/work-ranked.png)|
|15舰密阵|[原像素](before/scene-dense.png)|[原像素](after/scene-dense.png)|[原像素](before/work-dense.png)|[原像素](after/work-dense.png)|
|重战列压力混装|[原像素](before/scene-heavy.png)|[原像素](after/scene-heavy.png)|[原像素](before/work-heavy.png)|[原像素](after/work-heavy.png)|
|盾空甲存|[原像素](before/scene-shield-empty.png)|[原像素](after/scene-shield-empty.png)|[原像素](before/work-shield-empty.png)|[原像素](after/work-shield-empty.png)|
|甲空盾存|[原像素](before/scene-armour-empty.png)|[原像素](after/scene-armour-empty.png)|[原像素](before/work-armour-empty.png)|[原像素](after/work-armour-empty.png)|

[58步动作前后状态与14张必要过程图](operations.json)明确source_commit与capture_head_commit。拍摄源工作树随后提交为后版；拍摄时HEAD单独保留，不混作源身份。制作方记录不代替独立审运行。

[普通材质](operations/work-ordinary-material.png) → [可见敌舰观察](operations/work-enemy-observed.png) → [盾空存活](operations/work-shield-zero-alive.png) → [甲空存活](operations/work-armour-zero-alive.png) → [ranked身后瞄向](operations/work-ranked-rear-aim.png) → [五舰压力末态](operations/work-heavy-pressure.png) → [导航/开合/驻守/掉落回执](operations/work-pickup-receipt.png)。五舰仅内部渲染压力样本，掉落仅12.4K有限回执，不混作真实换舰/经济或G9。

source/image hash、JS语法/diff空白、几何/炮口/R/T与左侧像素检查通过，pageerror空。没有新资产、运行/Godot/性能验证。仍需整体观感与真实动态材质、提供者持续接线/任意组合/native/文件/离线、P3参数/逐舰来源、无人机canonical/真炮口、AI/长光束/DPI/输入/性能；A/B、整套品质和G2/G4/G9继续开放。
