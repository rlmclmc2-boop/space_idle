# R17 圆滑实体脊梁材质代表候选

这是接续[R16 结构与台座候选](../visual-r16-integrated-spine/README.md)的美术候选。[1440×900 正常主界面完整态原 PNG](evidence/full-ui-stage4.png)来自 Godot 4.7.2、既有恢复端口设置的第一星球四设施 `built` 临时状态；金币和探索度是夹具值。[同版五个建造可见状态](evidence/)及[受影响相位原图](evidence/phases/)也已归档。作者按原尺寸查看，并与用户认可的[固态实体环概念](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)并排比较。

本版保留真实四段独立 3D 环、球后深度遮挡、建筑自带台座和独立运动规则。环主体换成高细分圆滑截面，深青侧壁与青色外侧光槽围住带受光的暖象牙装甲曲面；结构肋和台座边缘收窄，完整环接头增加曲面套筒。鞍座与环面共用[原始 ImageGen 材质](../../../../assets/planets/orbital_spine/deck-albedo.png)，只作为真实网格的表面贴图，球后环没有被烘成图。Godot 贴图导入启用 mipmaps，SubViewport 使用 4x MSAA；相机与可建造业务未改。材质[生成提示词与原图 SHA](../../../../assets/planets/orbital_spine/imagegen-prompt.txt)、截图 SHA 见[哈希文件](evidence/sha256.txt)。

代表机位的三座工作设施取消通用黑圆座：旧插画底脚的 3D 根点降至本段曲面鞍座，精炼厂两条短入料槽、工坊开放工作湾两侧导轨、船坞泊位双轨分别属于本座已建环段，不依赖其他未建段；空间站保留自身圆形轨道接口。这是本次接口与深度关系的视觉候选，仍待独立审图，不代表原插画已经转换为完整 3D 建模。

受影响相位使用[固定驱动](evidence/phases/selected-driver.gd.txt)给完整态环带推进模拟时间（每帧 `TAU / (96 × 0.045)` 秒），取 0/24/43/51/72/87/96 帧；这是相位采样，**不代表实时帧率或正常运行速度**。作者原尺寸亲看 43/51/87：设施主体不再被环横切，也没有越过本次模块边缘；24 帧前弧中央仍有深色接缝，虽然套筒网格跨越两侧，画面仍可能读成窄断口，需独立视觉复审，不能据此宣称美术已通过。R16 旧视频不外推为本版动态。Godot `--check-only` 退出码 0，`git diff --check` 通过。
