# R9 舰内反应堆候选

本版使用新生成的 `1254×1254` 整体舱室图 `assets/ui/reactor/ship-hub-r9/working-bay-four.png`（源图与入库图 SHA-256 均为 `d3ac08d335e721b371c5016a2ee4fe6ff26fca400ffb6c578296306d317c3128`）。四口分别为实体双筒、六角盾单元、散热鳍及晶体装置；前景工作光读已生效供能，关机时露出静态设备和暗核心。四根斜管光流沿源图管腔的独立轴线与端口内缩；上方竖管的光层终点收在下米色实心环前，动画帧不在环上呈现方形亮斑。四口名称/增益落在内腔净空，右下名称避开左侧象牙壳；四条滑杆依各自斜控制板角度嵌入连续轨槽，比例在轨内。底台将等级/容量/已配/剩余与均分归组，将当前报价、循环数量及升级归组；斜切键面贴合台面凹槽。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99` / Mesa llvmpipe、正式主场景 `1440×900`、1×：[零供能整屏](reactor-r9-zero.png)、[四口已生效整屏](reactor-direct-active.png)、[MAX 报价整屏](reactor-r9-max.png)；[2 秒动态内容区](reactor-r9-flow.mp4)为 `808×835` 内容区加底部 1 像素编码填充，6 fps、无插帧。对应[运行驱动](flow-driver.gd.txt)/[日志](flow-runtime.txt)和[数量循环驱动](cycle-driver.gd.txt)/[日志](cycle-runtime.txt)均基于本版源码。动态驱动推进真实 Session 的模拟时钟并截取 12 帧，日志显示工作层更新 80 次；这是短片范围的工作状态检查，不代表长期或目标硬件性能通过。

驱动通过公开 Campaign 恢复入口临时开放反应堆及凝聚，通过公开 Economy 入账提供购级预算；不是自然关卡开放或自然收入的证明。循环数量按钮按 `×1 → ×10 → MAX → ×1` 更新真实 Owner 报价，日志分别为 10、550、752、10 铀，切换期间等级保持 1；执行仍由 Owner 的购级接口完成。[真实鼠标驱动](inset-mouse-driver.gd.txt)/[日志](inset-mouse-runtime.txt)在倾斜滑杆上点击后，武器已接纳比例从 25% 到 24%，证明旋转后的控件仍可命中 Owner 直接分配。入口 `--check-only` 与 `git diff --check` 均通过。此为待根线程视觉审阅的分支候选，未合 main；共享宿主与右侧战场由整体组维护。
