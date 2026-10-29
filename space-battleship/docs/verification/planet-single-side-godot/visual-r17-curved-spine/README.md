# R17 圆滑实体脊梁材质代表候选

这是一张先交审的**代表机位**，接续[R16 结构与台座候选](../visual-r16-integrated-spine/README.md)。[1440×900 正常主界面完整态原 PNG](evidence/full-ui-stage4.png)来自同版 Godot 4.7.2、既有恢复端口设置的第一星球四设施 `built` 临时状态；金币和探索度是夹具值。源夹具和日志见[evidence](evidence/)。作者已原尺寸亲看画面，与用户认可的[固态实体环概念](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)并排比较。

本版保留真实四段独立 3D 环、球后深度遮挡、建筑自带台座和独立运动规则。环主体换成高细分连续圆滑截面，深青侧壁和细青侧槽围住带受光的暖象牙装甲曲面；每段一条较宽的结构肋，段间耦合器有少量青色状态节点。鞍座与环面共用[原始 ImageGen 材质](../../../../assets/planets/orbital_spine/deck-albedo.png)，只作为真实网格的表面贴图，球后环没有被烘成图。Godot 贴图导入启用 mipmaps，SubViewport 使用 4x MSAA；相机与可建造业务未改。材质[生成提示词与原图 SHA](../../../../assets/planets/orbital_spine/imagegen-prompt.txt)、本次截图 SHA 见[哈希文件](evidence/sha256.txt)。

Godot `--check-only` 退出码 0，`git diff --check` 通过。此次只固定单张代表画面，不把 R16 的视频外推成新材质的动态证据；设施经过重点相位的受影响复核仍在继续。本候选还需原 Astra 审美术层次。
