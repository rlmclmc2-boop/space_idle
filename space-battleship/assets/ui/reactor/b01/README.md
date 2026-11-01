# 当前分件反应炉资产

制作、坐标和交付关系见 `docs/game-design/art/modules/reactor-asset-contract.md`。实际安装保持808×835内容口，使用同源端口、安装帧和路径，不依赖整张概念图裁切。

`generate_faceted_reactor.py`由本地Blender生成独立机体/核心/房间/机台、压力管路和真实工作Mesh，写出GLB及layout。命令：`blender -b -t 4 --python assets/ui/reactor/b01/generate_faceted_reactor.py -- --export-glb`。分件倒角和法线在合并固定结构前解析。

`generate_plasma_atlas.py`用本地NumPy/Pillow作确定性三维发射/吸收积分，输出32个原始体积帧到`/tmp/reactor-plasma-clean`；`pack_plasma_atlas.py`只打包完整且配方哈希一致的32帧，写入`plasma-volume.png/json`。依次运行两脚本即可重建。它只含独立等离子体，不含机壳/文字/管道；运行时在原等离子体网格上以发光材质采样邻帧，不做实时体积步进，也不新增覆盖控件。软件无生成次数配额，不调用云端收费接口。

工作Shader共用`faceted-work-common.gdshaderinc`；普通工作面使用混合材质，等离子体使用发光材质。几何源深度负责真实机壳遮挡，安装帧负责热区/生长/输送坐标。所有原生文字、费用、滑杆与按钮由Scene保留。
