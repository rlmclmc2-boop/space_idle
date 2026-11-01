# 分面反应堆运行资产

规范：[M3](../../../../docs/game-design/art/modules/reactor.md)及[安装契约](../../../../docs/game-design/art/modules/reactor-asset-contract.md)。制作状态只见当前B01 HANDOFF。

- `generate_faceted_reactor.py`：本地Blender生成源；`blender -b --python generate_faceted_reactor.py -- --export-glb`。
- `faceted-reactor.glb`：稳定ID的独立机体、工作结构和管道节点，聚合包共享材质；节点可单独替换/实例化，并非不可拆的场景贴图。
- `reactor_ports.json`：预制接口中心、方向、口径及插入深度的输入；`faceted-layout.json`记录实际导出边界、三维接口及等比变换。
- `faceted-surface`／`faceted-depth`：固定相机下的静态受光、真实结构阴影和16位深度采样。
- `faceted-canvas-background`／`faceted-canvas-work`：静态缓存合成及原始工作几何的投影、遮挡和过程材质。渲染缓存不含文字/按钮，也不替代可编辑的分件GLB。
- 两份SVG为透明模块身份图及滑块；按钮消费公共BridgeTheme，文字/分配/费用全部是Godot原生控件。
