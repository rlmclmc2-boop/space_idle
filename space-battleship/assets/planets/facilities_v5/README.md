# R5 设施模型（实施候选）

`art_sources/planet_facilities_v5/build.py` 与四个 `.blend` 是可编辑来源；脚本导出四个同名 GLB。本版以 [R5 用户认可的简化造型稿](../../../docs/verification/planet-single-side-godot/visual-r5/README.md)为轮廓/配色参考，不把 imagegen 平面辅助视图当精确工程图。材质使用大块暖象牙、深蓝结构和少量青/琥珀工作灯，不沿用 R4 写实铜管/厚重碎件。`model-stats.json` 仅记录几何规模，不能代表画面验收或用户设备性能。

导出节点保留明确的可动枢轴。当前运行时 `scripts/planet_facility_scene.gd` 按正常视觉时钟驱动：空间站仍使用 GLB 居住环与太阳翼；精炼厂、工坊、船坞隐藏旧白模网格，改用分层透明美术。精炼厂可见散热门与沿入料带移动的矿料，工坊可见贴梁滑座与下方工具行程，船坞可见上层吊机往复及泊位环轻微明暗循环。泊位环原 `DockCollarSpin` 枢轴数值仍转，但当前图层没有可辨旋转效果，不以枢轴数值宣称画面旋转通过。建筑仍纯观看，操作留原面板。

实体带概念整体返修候选在原 `build.py` 的空间站分支把过宽太阳翼收为短供能片，增加有承力底座的圆形站体、天线和仍独立旋转的居住环；可编辑 `auto_explore.blend`、导出的 `auto_explore.glb` 与统计同版。另三座的原 GLB 枢轴保留，运行主体改接[三张概念约束的新透明图及准确生成提示](illustrated/concept-spine-asset-prompts.txt)：精炼厂金顶、橙色开放湾工坊、内泊小艇的双臂船坞；旧图保留作为来源和活动层配准参考。与承重脊表面[新纹理及来源](../orbital_spine/deck-concept-spine-prompt.txt)共同使用，不把单张素材视作整屏通过。

整体环返修继续时，工坊与船坞分别替换为[跨脊开放工坊及完整提示链](illustrated/workshop-through-node-prompts.txt)、[短喉双臂船坞及提示链](illustrated/shipyard-through-node-prompts.txt)。两图仅保留节点内部短通道，外部长弧仍是 Godot 的独立 built 网格段；前者的原滑座工具、后者的吊机与泊位层仍按原业务时钟工作。两张素材与真实环的最终共同剪影仍待整体审，不因资产本身完成而宣称通过。

精炼厂/工坊随地表相位改变位置和切线姿态，地表足座压入表面，接触阴影投射至解析椭球；空间站独立绕轨，船坞为轨道外侧固定服务位。具体运行静帧、连续证据与限制见本轮验证目录；这份资产说明本身不宣称接触、净空或全星球已通过。
