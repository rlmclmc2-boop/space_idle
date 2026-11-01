# 环向建筑资产源

当前制作依据是原设计图：`8136cef8:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png` 的固态完整态右图，以及 `1eda07fd` 同目录 `solid-integrated-spine-stages-closed.png`。目标是连续宽实体建筑带与嵌入其上的四处功能空间，远弧由球遮挡，近弧越过球下暗空间并保持间隔。

`build_v23.py`用 Blender 4.3.2 生成 `concept-v23.blend` 和 `concept-v23.png`。四设施分别拥有实体带的一段：空间站观察区、精炼厂热工区、工坊开放制造槽和船坞开口泊位。屋面轮廓、深色承力侧壁及青色服务线沿同一截面连续，制造槽保留下方承力段，船坞为外伸开口。旧版源码留在本目录作为独立历史资产，不参与当前导出。

`export_v23.py`从同版 Blend 导出 `assets/planets/facilities_v9/` 的四件 GLB，将各段烘到同一轨道中心坐标，同时保留运行所需的运动枢轴名称。`planet_facility_scene.gd`以共同轨道基变换显示它们；独立建造归属、球后遮挡、球与环分别转动及现有业务接口由 Godot 继续负责。图稿和运行资产需以当前固定源码一起判断。
