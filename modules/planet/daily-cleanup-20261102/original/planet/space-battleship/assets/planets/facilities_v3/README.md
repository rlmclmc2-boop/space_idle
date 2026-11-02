# 星球设施第三版视觉候选

第二版已被根审否定为积木化，不能凭 GLB/Blender 文件存在宣布品质提升。本组按新 imagegen 建筑参考重做实际可见结构与材质：分段环形居住舱和观景核、水平胶囊处理罐及铜色汇流管、带装甲分件/玻璃顶的拱形装配厅、分段骨架与泊位导轨的开放船坞。

可编辑源与构建脚本位于 `art_sources/planet_facilities_v3/`；`build.py` 重建四个 `.blend` 和几何 GLB。源内有真实软倒角、材质分面、工艺管路与光伏结构。静态结构/活动硬件分别合并，保留 Facility/Motion 枢轴，统计见 [model-stats.json](model-stats.json)。数量仅说明资产组成，不是品质或性能结论。

[`material-atlas.png`](material-atlas.png) 为内置 imagegen 生成的四区基础颜色图集：象牙装甲、深青结构、蓝色光伏、铜色工艺材质。提示词见 [imagegen-material-request.json](imagegen-material-request.json)。原始 PNG 字节直接复制，未经额外图像处理。几何 UV 在源脚本映射到对应图集区域；Blender 源保留图集连接，GLB 只导出几何/基础材质，Godot 将同一外部图集共享给四组建筑，保留其金属度、粗糙度与独立灯色。此处不冒称有完整法线/粗糙度贴图集。

地表/轨道分工、切平面、遮挡、暂停和只观看语义保持；工坊地表与固定近轨船坞仍为设计建议。最终判断依据为 [Godot 4.7.2 实机修订](../../../docs/verification/planet-single-side-godot/visual-r2/README.md)，不是参考图或 Blender 统计。没有实施可见网格球 B 路线或同条件性能基准。
