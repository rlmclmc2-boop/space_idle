# R12 精炼厂分层美术与入料循环候选

这是继 R11 工坊窄审通过后的**精炼厂独立候选**，不沿用工坊的视觉结论。三张未改像素的透明 ImageGen 草稿接入原 `refinery.glb` 根：`refinery-body.png` 保留 R5 认可的低矮炉舱、深蓝凹入的琥珀炉口、双大矿斗与宽入料带；两张散热门图在原 `IntakeWheelLeft/Right` 枢轴下独立开合。三枚小型琥珀矿料标记沿图中入料带向炉口循环移动，使实际约 100px 的建筑有可见的工作过程。旧白模网格仅对精炼厂隐藏；原地表 UV 锚点、相位、接触影、球体遮挡和业务均未改。原工坊实现保持不变。

请审 [20 秒原尺寸实机循环](evidence/refinery-cycle.mp4)和 [20 张连续 1440×900 帧](evidence/frames/)，重点看双矿斗、炉口、入料带在屏幕尺寸的辨识度，矿料是否始终在带面上并走向炉体，散热门动作是否可读，以及随地表转动时的落脚与遮挡。[00](evidence/key_00.png)、[10](evidence/key_10.png)、[19](evidence/key_19.png) 是原尺寸关键帧。作者已亲看全部 20 帧与原尺寸关键帧，未见主体或活动层在本段消失；动作与造型最终结论仍由独立审者裁定。墙钟采样 `135.396–154.890s`，视频 1fps 仅为证据采样，非引擎帧率。[operations.json](evidence/operations.json)记录原业务夹具与星球相位；其中旧工坊枢轴条目来自复用取证驱动，不用作精炼厂动作证明。

原始图来源为本地 ImageGen 草稿：`refinery-body.png` 对应 `exec-ab1cf7c8-efea-467d-8bb6-48609be515dd.png`，左右散热门分别对应 `exec-b7d43ce4-be2b-4844-8ab3-caec5a2c3e60.png`、`exec-0f30fa5b-5bd2-4137-aa2c-a3fdff12de9d.png`，只复制原 RGBA 文件，未用脚本改图。

正式主场景使用官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:91`、Mesa llvmpipe；启动错误为空，原业务夹具加载成功。[驱动](evidence/driver.gd.txt)、[运行日志](evidence/runtime.txt)、[资源导入日志](evidence/godot-import.txt)、[入口脚本检查](evidence/script-check.txt)与 [SHA256SUMS](SHA256SUMS)归档。本候选不代表船坞、六星球或整轨净空通过。
