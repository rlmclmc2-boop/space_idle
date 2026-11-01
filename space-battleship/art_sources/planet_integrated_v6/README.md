# 星球一体环与设施：新资产制作依据

旧 `facilities_v5` 建筑形体不再作为本轮造型基础。批准的[完整态](../../docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)与[逐建态](../../docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)给出整体方向；本组以同一宽装甲环截面和四个不同用途的承力节点重新造型。

环顶为单块宽装甲面，暗缝只作细接合线；深蓝下腹和外侧青色服务线沿各独立建造段连续。设施节点的低位白色承压壳进入该截面，环从节点一侧进入、从另一侧离开。站为低位环枢，炉为带双料斗的热工节点，工坊为敞开的跨环门架，船坞为承力壳延伸出的双臂泊位。结构件、工作口和停靠艇按原尺寸辨识，避免四个盒体放在轨道上。

新模型由 `build_facilities.py` 独立生成到 `assets/planets/facilities_v6/`。每件保留 `Facility` 根和现有动画枢轴名；业务状态、owned 归属和探索船逻辑继续由原 Godot 接口提供。先看完整态及逐建端面，再看换角度动态；新资产未经过这些检查前不标记通过。
