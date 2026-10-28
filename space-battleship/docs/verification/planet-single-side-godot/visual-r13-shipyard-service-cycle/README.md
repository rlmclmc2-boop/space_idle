# R13 船坞分层美术与泊位动作候选

这是船坞的独立视觉候选；R11 工坊已通过的连接窄审与 R12 精炼厂候选均不替船坞背书。三张未改像素的透明 ImageGen 草稿接入原 `shipyard.glb` 根和原 `CraneSlide`、`DockCollarSpin` 枢轴：固定主体有尖高单侧主脊、截面不同的上下开放悬臂；独立吊机沿上层服务臂往复；独立裁片泊位环覆盖上层端口并循环发光。旧船坞白模网格隐藏。船坞仍使用既有球外、站轨外独立服务位，建筑仍纯观看，业务未改。

请审 [20 秒原尺寸实机循环](evidence/shipyard-cycle.mp4)及 [20 张连续 1440×900 帧](evidence/frames/)，重点看约 80px 尺寸下主脊、开放双悬臂、吊机与泊位环的辨识度，吊机是否始终搭在上层臂上，以及球外服务位是否读得清楚。原尺寸关键帧为 [00](evidence/key_00.png)、[10](evidence/key_10.png)、[19](evidence/key_19.png)。作者已亲看全部 20 帧和关键图，未见吊机或泊位环在本段脱离；动作与造型是否足够可读仍交独立审者裁定。这 20 秒不能代表整轨净空或所有星球。墙钟采样 `0.197–19.644s`；视频 1fps 是证据采样率，非引擎帧率。[逐帧轨迹](evidence/operations.json)记录原枢轴和星球相位，吊机枢轴约在 `±0.50` 模型单位范围内往复，不能代替画面判断。

原始图来源为本地 ImageGen 草稿：`shipyard-body.png` 对应 `exec-8084178a-0ffc-487e-a47e-5ead8e27f3c5.png`，`shipyard-crane.png` 对应 `exec-37310f8d-e91e-4004-97ac-d53d57e95249.png`，`shipyard-berth-ring.png` 对应 `exec-8ef0ef3e-9b04-49ad-9d3e-dbbdc7e27bf5.png`。资产只复制原 RGBA 文件，泊位环在运行时用 `AtlasTexture` 取透明画布区域，未用脚本改图。

正式主场景使用官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:91`、Mesa llvmpipe。启动错误为空，原业务夹具加载成功。[驱动](evidence/driver.gd.txt)、[运行日志](evidence/runtime.txt)、[资源导入日志](evidence/godot-import.txt)、[入口脚本检查](evidence/script-check.txt)与 [SHA256SUMS](SHA256SUMS)归档。没有改共享宿主、全局导航、星球贴图、经度接缝、暂停门控或 H1 端口。
