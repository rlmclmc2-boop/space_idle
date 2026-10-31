# 整舰能源控制中枢 R3（整体空间候选）

本稿回应 `6ba06d32` 的“小整机”问题：中央球形反应炉仍是主角，四路周边结构改为整舰系统的**供能调节接口**，不在反应炉舱内摆小炮、小护盾机、小熔炉和小凝聚机。四条短接入核，粗管从各接口继续穿进舱壁/地板并延伸出画幅，表示能量送往舰体其他位置。前缘保留一处整组主控台，四个端口旁各有独立读控面的位置；所有结构共用舱室透视、承载与遮挡。

| 系统 | 本稿接口身份 |
|---|---|
| weapons | 左上齐平双轨脉冲耦合口和橙色导流，避免炮管朝外的缩小炮台 |
| defence | 右上六角场调节端口及蓝色舰内干线 |
| smelting | 左下琥珀热交换栅与地板下导流 |
| condensation | 右下晶格滤波端口及右舷干线；三设备态整套消失 |

| 状态 | ImageGen 原生图 | 1440×900 固定宿主配合图 |
|---|---|---|
| 四系统 | [原图](reactor-four-raw.png) | [整屏](reactor-four-host-layout.png) |
| 三系统 | [原图](reactor-three-raw.png) | [整屏](reactor-three-host-layout.png) |

对照过 [S5 原始场景](https://github.com/rlmclmc2-boop/space_idle/blob/b4d2adc8/test/evidence/seven-parent-20261017/17-reactor6.png) 与 [M3/V3 规范](../../../../game-design/art/modules/reactor.md)：沿用的是统一控制台内核心、配电/管路和对应系统读控的关系，不沿用 S5 设备造型。画面按 [`4f4d63d5` 固定作图范围](https://github.com/rlmclmc2-boop/space_idle/blob/4f4d63d57ddc215453993cce739eaa3eecfc4198/space-battleship/docs/ui-redesign-plan/shared-host-shell/reactor-drawing-v1/README.md) 放进内容 808×835、宿主偏移 (0,65)，安全内区仍为 (16,16,776,803)。

四系统原生 1233×1275 PNG 为 ImageGen `exec-c3e0fcb6-71b4-47f9-9e62-9aa693e9fd14.png`，SHA256 `6769a3c0bf9c9a5afd24850e4106be660f7ece52f7a8e843236213f63dcbdaea`；三系统图基于它编辑，移除了右下凝聚端口、短接、舰内干线和读控，原生输出 `exec-fb6825d9-5c84-48d1-bcee-c4e3744449c3.png`，SHA256 `de37189f46bf1334bcbb58ddff774e2105fe31464944652bd6d5ab4da119b739`。原图未拼贴或后补文字。`compose-host.sh` 将原图按宽 808 等比缩放、居中裁少量环境，再置入 [`shared-host-reference.png`](shared-host-reference.png) 的 (0,65)。两张整屏与参考的顶部 1440×65、右战场 632×900 区域逐像素 AE 均为 0；它们是静态模板合成，非 Godot 截图。

本轮先审“整舰能源中枢”的空间表达与三/四系统状态。图中亮灯和读控仍烘焙在概念图中，不是可用控件或动态工作证明；四路 176×112 读控空间、132×32 滑杆命中区、主控费用/反馈、无字分层及 1×安装锚点仍待方向确认后制作与实测。未改 Godot、公共宿主、战场、业务或 `main`。
