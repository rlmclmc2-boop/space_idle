# 反应堆 R7 斜玻璃工作光候选

承接 [R6 嵌入工作口](../installed-r6/README.md)。下方炼铁、凝聚口的玻璃下沿是相反斜率，原 146×44 矩形工作层越过玻璃盖住象牙壳。现在两个 shader 共用按模块区分的斜边 UV 遮罩：左下从左到右收高，右下镜像展开；工作层在 `power=0` 时 alpha 为 0，显露底图玻璃与壳体。四口的局部工作身份分别为武器三路导流脉冲、盾场错列网格、炼铁竖热栅、凝聚向中心收束。功能名仍在口上沿，倍率加粗放大，以克制的暖/冷色区别于名称。整宽工作台、反馈颜色和 Owner 行为沿 R6。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/Mesa llvmpipe、正式主场景 1440×900、1×：[四口运行](four-active.png)、[零负载/MAX 报价](zero-load-max.png)。[无遮挡 12 帧连续片段](flow-1x.mp4)为 808×835 内容区加 1 像素编码填充，6 fps、无插帧。[截图驱动](capture-driver.gd.txt)/[日志](capture-runtime.txt)与[连续帧驱动](flow-driver.gd.txt)/[日志](flow-runtime.txt)用于复核同版画面、运行动态和引导遮挡。驱动通过公开 Campaign 恢复入口临时开放模块，并通过公开 Economy 入账供费，非自然关卡进度。录制结束 `running=true, paused=false`；ALSA 无声卡回退为本机环境。

本次只复核受遮罩、工作光、倍率层级影响的画面。R6 已有的 Owner 直接分配、报价和真实鼠标证据仍在其证据目录。此版为待原审视觉候选，不合 main；整体宿主与右侧战场归共享整体组。
