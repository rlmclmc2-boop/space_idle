# 星球轨道设施实体资产

当前运行时 `scripts/planet_facility_scene.gd` 加载本目录四个 GLB，作为同一倾斜轨道面上的设施实体。四段独立 owned 承力环由 `scripts/planet_orbital_spine.gd` 生成；设施局部 X 轴通道与环切线对齐，设施自身不会接管相邻环段的归属。

可编辑来源与导出脚本位于 `art_sources/planet_facilities_v5/`：`build_station_node.py`、`build_refinery_node.py`、`build_workshop_node.py`、`build_shipyard_node.py` 分别重建同名 `.blend` 与本目录 `auto_explore.glb`、`refinery.glb`、`equipment.glb`、`shipyard.glb`。运行时保留站 `HabitatRingSpin`、炉 `IntakeWheelLeft`／`IntakeWheelRight`／`CoolingShutters`、工坊 `GantrySlide`／`ToolArmSweep`、船坞 `CraneSlide`／`DockCollarSpin` 这些既有可动节点。四设施业务状态仍由现有星球面板快照提供，GLB 只承担观看表现。

`illustrated/` 中的图是概念与局部形体参考，不是运行时分层贴图，也不作为几何或整体验收证据。当前制作、批准概念和原尺寸验证边界统一见[星球整体结构入口](../../../docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。`model-stats.json` 按当前四个 GLB 导入 Blender 后的网格和三角面数记录规模，不代表性能或视觉通过。
