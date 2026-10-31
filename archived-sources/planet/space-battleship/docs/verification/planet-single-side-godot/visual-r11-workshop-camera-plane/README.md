# R11 工坊连接坐标返修候选

R10 独立视觉审退回：原尺寸第 00、10、19 帧里，下方工具有时突出横梁上方，另有小段落到工作湾前缘或右前脚，滑座与工具缺乏连续连接。代码原因是 `Sprite3D` 面向相机，但裁图中心仍沿倾斜的模型局部 Y 摆放；滑座水平行程和伸缩连杆又分别使用局部 X/Y，图像各段不在同一画面坐标系。

本轮将模型逆变换后的**相机右、上、前**三个单位向量作为唯一基准：两张未修改的原图裁片沿相机上方向复原原图坐标；滑座沿相机右方向走原 `GantrySlide` 水平行程；伸缩段两端和下方工具沿相机上方向同轴定位。原 `ToolArmSweep` 枢轴仍由游戏时钟驱动，其完整周期映射到横梁下方 `0–0.35` 模型单位的伸出，避免向上穿梁。两张图仍在 R9 的前置深度并保留球体深度测试。工坊主体、原 3D 锚点、地表随转、暂停门控和其他建筑未改。

作者已亲看 [20 张连续 1440×900 原尺寸实机帧](evidence/frames/)和 [20 秒原尺寸循环](evidence/workshop-cycle.mp4)，并对工作湾做临时放大自查：第 [00](evidence/key_00.png)、[10](evidence/key_10.png)、[13](evidence/frames/frame_13.jpg)、[19](evidence/key_19.png) 帧均未见工具越过横梁，滑座位于梁下；工具在工作湾前段运动，连接的最终可读性仍请原独立审者裁定。20 帧墙钟采样 `135.684–155.278s`；1fps 是证据视频采样率，不是引擎帧率。[逐帧轨迹](evidence/operations.json)保留原枢轴和星球相位，不能代替视觉判断。

正式主场景使用官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:91`、Mesa llvmpipe。启动错误为空，原业务夹具加载成功。[驱动](evidence/driver.gd.txt)、[运行日志](evidence/runtime.txt)、[资源导入日志](evidence/godot-import.txt)、[入口脚本检查](evidence/script-check.txt)、[SHA256SUMS](SHA256SUMS)一并归档。本证据只请求审代表工坊的连接与动作；不代表其他建筑或更大范围验收。
