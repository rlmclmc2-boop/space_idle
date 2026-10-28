# 反应炉设备本体前缘装配候选 R3

R2 的四块同款正面板在真实画面中仍像悬浮卡，字号与主动作也低于既定预算。本候选在 1440×900 Godot 4.7.2/native Session/Xorg:99 实屏核对。四台设备沿原黑色水平槽承接新的原生 HSlider（154×32），设备各自的象牙壳与深青金属前缘向下包住三行读数；源 SVG 和 2× PNG 位于 `assets/ui/reactor/ship-hub-r4/`，分别为武器的散热机翼、盾甲的六角护边、铁产出的压铸肋、碎片的晶面托。原设备识别窗、核心和实体供能管保持可见。增益18px、手动/免费及有效16px。中央控制台以 500×151 梯形前面承接原底座，主购级151×44、次动作74×40，反馈独占玻璃面底行。

| 实屏 | 核对点 |
|---|---|
| [四路运行](reactor-mount-r3-active.png) | 四设备普通短读数完整；核心/管口工作层由实际负载驱动，底部“供能已更新”在控制台面内。 |
| [四路鼠标草稿](reactor-mount-r3-four-mouse-preview.png) → [整组确认](reactor-mount-r3-four-mouse-applied.png) | 主视口鼠标将四路从25拖到1/0/1/0，当前→目标的增益/手动/有效三行完整，确认前核心仍按旧负载工作；整组确认回执成功。 |
| [禁用](reactor-mount-r3-disabled.png)、[焦点](reactor-mount-r3-focus.png)、[悬停](reactor-mount-r3-hover.png)、[按下](reactor-mount-r3-pressed.png)、[购级后](reactor-mount-r3-purchased.png) | 151×44 主购级按钮五态对比与等级1→2真实结果。 |

[状态驱动](states-driver.gd.txt)/[日志](states.log.txt)、[四路鼠标驱动](four-mouse-driver.gd.txt)/[日志](four-mouse.log.txt)留存。驱动使用公开 Campaign/Economy API 临时授予开放与购级预算；截图前经 Session `dismiss_guidance` 与宿主 `_sync_guidance` 结束解锁提示，并将鼠标移出设备以清除 tooltip。游戏自然进度/收入未在此证明。未改 `main.gd`、规则/配置或核心动态；未重跑此前业务长流程及硬件性能。宿主顶部0..65公共导航仍由整体组负责。
