# B01 R10：现行资产同版作者整屏与动态

运行资产固定于 `implement/reactor-centered-godot@5a3e3a81483353dec27b2231f6c09497d8027a74`；采证时制作入口为 `implement/reactor-centered-godot@4ff71bd23b312dc4ead32ac9363cbe63b3ce4c25`，该后续提交仅更新入口说明。画面来自 Godot 4.7.2、本地既有 native 绑定、1440×900 桌面窗口。四路正载由 Reactor Owner 接纳；未改生产配置、Owner 或端口。`capture-summary.txt` 记录实际状态、游戏时钟与录屏流信息。

八张 `reactor-r10-controlled-{1,2,3,4}-{zero,active}-1440x900.png` 是现行资产的完整整屏。`reactor-r10-controlled-author.gd` 只在预览进程缩窄 `reactorModules` 参数，并给隐藏路补中性发布因子；每次数量从零分配开始再由 Owner 均分，截图前核对模块数、负载和控制行数。因此这八态证明隔离显隐及读序，不证明自然解锁。

`reactor-r10v-final-1x-250frames.mp4` 从同版四路正载主游戏窗口实时录制，1440×900、30 fps、250 帧，**实际 8.3667 秒**。`reactor-r10v-final-author-preview.gd` 在游戏启动和正载均分后发出 marker，`reactor-r10v-capture.py` 据此用 X11Grab/FFmpeg 录制；它们沿用前版驱动，只将输出名前缀转为 R10。运行日志记约 10.27 游戏秒、249 个 active frame。第 2/5/9 秒完整整屏另存 PNG 供相位对照。录屏受捕获本身影响，不能当目标硬件性能报告。

`reactor-r10-edge-author.gd` 在完整四路 Owner 上提交均分、盾路归零、盾路 1/100 容量、切走并重开反应堆页；归档 `mixed-zero`、`low-positive` 和 `reopened-low-positive` 三张整屏。日志记录盾路实际负载 0.01，隐藏期间视觉相位保持 4.7667，重开后继续至 5.3。截图前等待命令提示消失。

作者逐张看八态、边界图和第 2/5/9 秒整屏，并抽看录屏内部帧：当前炉窗是料嘴竖流入较宽亮熔池，再从右缘短排液；热面明暗随相位变化，原尺寸的细部运动仍较轻。盾场在正载展出外弯半透明面，盾路归零时收起；晶柱在连续片中长高。四机钢银铜受舱室冷暖光，但整页材质、炉内流动可辨度及盾场空间体量尚需独立视觉判断。自然解锁、最终公共组合和目标硬件性能也尚未验收。本包是同版作者证据，不记录通过结论。

`SHA256SUMS` 列出包内除自身外各文件的内容哈希。证据独立存于本 Git archive，不置于制作树或 Library。
