# R3 星球设施检查点

可编辑 Blender 源和 `build.py` 在 `art_sources/planet_facilities_v4/`。本轮去掉整片深色地表底板、减少暖色主体上的暗缝；工坊用连续拱壳，精炼厂用嵌入式支座和宽胶囊罐，船坞改细开放肋架及窄导轨，轨道站减少碎装甲。统计见 `model-stats.json`，不以分件/三角数宣称品质或性能。

`material-atlas.png` 字节复用 V3 的原 imagegen 图集；来源与提示词仍见 [V3 图集记录](../facilities_v3/imagegen-material-request.json)。本版仅光伏/铜材使用图集，象牙与青色结构使用连续基础材质。没有伪称新生成图集或完整 PBR 贴图。

地表模型沿解析球面法线贴附，支脚略嵌表面，新增球面投影的透明接触阴影；仍须实际完整绕转检查接地、球缘及背侧遮挡。建筑纯观看，操作保持独立；设施功能/业务未改。本轮为待审候选，见 [R3 检查点](../../../docs/verification/planet-single-side-godot/visual-r3/README.md)。
