# 反应炉局部操作台装配候选 R2

这是 `implement/reactor-centered-godot` 对 R1 读数截断及过小输入区的修订。四台设备各接一个与象牙外壳相连的局部操作面（源 SVG 和 2× PNG 在 `assets/ui/reactor/ship-hub-r4/`）；原设备识别窗及管口可见。每路原生 HSlider 154×32，读数分为增益、手动/免费、有效三行，仍读取原 owner 当前/草稿模型。中央控制面按原底座轮廓扩为 410×132，保留等级、容量、费用、四动作和反馈。前版已确认的核心动态、下方两路管光和购级状态样式保持。

同版 Godot 4.7.2 / native Session / Xorg:99 / 1440×900 实屏：

| 证据 | 核对点 |
|---|---|
| [四路工作](reactor-mount-r2-active.png) | 设备身份、工作核心及读控一体；各路显示增益×1.13、手动25、有效25；中央容量100/已配100。 |
| [四路草稿](reactor-mount-r2-four-mouse-preview.png) → [整组确认](reactor-mount-r2-four-mouse-applied.png) | 四个真实鼠标滑杆由25分别拖至1/0/1/0；草稿画面显示完整短值，核心仍按确认前负载工作；确认后 owner 回执成功且工作层随实际零/非零负载变化。 |
| [禁用](reactor-mount-r2-disabled.png)、[焦点](reactor-mount-r2-focus.png)、[悬停](reactor-mount-r2-hover.png)、[按下](reactor-mount-r2-pressed.png)、[购级后](reactor-mount-r2-purchased.png) | 同版主购级按钮状态和等级1→2；浅暖底各状态保持深字可辨。 |

[四路鼠标驱动](four-mouse-driver.gd.txt)与[日志](four-mouse.log.txt)、[购级状态驱动](states-driver.gd.txt)与[日志](states.log.txt)留存。驱动在截图前通过 Session 的公开 `dismiss_guidance` 与宿主 `_sync_guidance` 正常结束待处理的“反应炉已解锁”等提示，并把鼠标移出控件，避免提示/tooltip 遮住反应堆。开放权限、购级预算仍由驱动通过公开 Campaign/Economy API 临时注入；不代表自然进度。只回归本次更改影响的控件鼠标、读数和购级状态，未重跑完整业务测试或硬件性能测试。旧宿主 0..65 导航仍待整体组接入；未改 `main.gd`。
