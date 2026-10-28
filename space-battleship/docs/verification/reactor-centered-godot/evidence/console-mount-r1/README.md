# 反应炉设备读控与主控台装配候选 R1

本候选基于 `implement/reactor-centered-godot` 的 `ae0508ee`，仍在 1440×900 Xorg:99、Godot 4.7.2、真实 native Session 中截图。内容根仍为 (0,65,808,835)；`main.gd` 及业务模型/规则未改。开放权限和购级预算在驱动中临时通过公开 Campaign/Economy API 注入，因此这些截图不证明自然游戏进度。

[四路工作画面](reactor-mount-active.png)显示每路读数落于设备显示窗，原生水平滑杆位于设备自带的水平槽。原 776×132 的漂浮大板缩至中央控制台面 (238,762,333,110)，等级、容量、费用、动作及反馈在那里读取。两条下方光流端点改沿可见的左右下斜实体管道，核心口到设备口的方向与遮挡可在此图核对。原有核心动态没有重做；此图仅作为新的装配候选供审。

[禁用](reactor-mount-disabled.png)、[焦点](reactor-mount-focus.png)、[悬停](reactor-mount-hover.png)、[按下](reactor-mount-pressed.png)来自同一版实机；主购级按钮的各状态字色与底色对应，未靠静态补字。[四路拖动草稿](reactor-mount-four-mouse-preview.png)与[确认回执后](reactor-mount-four-mouse-applied.png)来自主视口真实鼠标事件；[日志](four-mouse.log.txt)记录四个值由 2500 分别变化至 100/0/100/0、预览有效且整组确认成功。[状态驱动](states-driver.gd.txt)、[状态日志](states.log.txt)和[四路鼠标驱动](four-mouse-driver.gd.txt)可复核采样过程。

宿主顶部 0..65 仍为旧导航，属于整体组公共壳/路由协同范围。本候选未跑此前已通过的完整业务长流程或硬件性能测试；本次仅回归受控件位置影响的四路鼠标及购级状态。
