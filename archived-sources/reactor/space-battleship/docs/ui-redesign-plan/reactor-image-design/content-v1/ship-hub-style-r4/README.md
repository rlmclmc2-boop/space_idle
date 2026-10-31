# 整舰能源中枢 R4：克制材质与功能光候选

本轮在已认可的 [`87f0a518` 整舰能源中枢](../ship-hub-r3/README.md)上只收敛美术表现。中央球形核心仍主导画面，四个接口仍嵌入舰体舱室，短接入核，粗管继续穿过壁/地延伸至整舰；前缘只有一处主控。四路身份为武器双轨耦合、防御六角场调节、冶炼热交换栅、凝聚晶格滤波，不恢复独立小机器或功能卡片。

项目匹配的准确参考为[正式战舰图](../../../../../assets/ships/fleet_20261019/player/04-battleship.png)，以及用户认可的 R5 建筑四图（`1776fbde`）：[refinery.png](https://github.com/rlmclmc2-boop/space_idle/blob/1776fbde/space-battleship/docs/verification/planet-single-side-godot/visual-r5/designs/refinery.png)、[shipyard.png](https://github.com/rlmclmc2-boop/space_idle/blob/1776fbde/space-battleship/docs/verification/planet-single-side-godot/visual-r5/designs/shipyard.png)、[station.png](https://github.com/rlmclmc2-boop/space_idle/blob/1776fbde/space-battleship/docs/verification/planet-single-side-godot/visual-r5/designs/station.png)、[workshop.png](https://github.com/rlmclmc2-boop/space_idle/blob/1776fbde/space-battleship/docs/verification/planet-single-side-godot/visual-r5/designs/workshop.png)。本稿去掉 R3 的密集灯带、镜面高光、碎机械线及强电弧，将核心改为层次较安静的青色能量体，四端口只留识别功能所需的光；每个端口下方保留一处嵌入式直接滑杆视觉位置。**R4 仍是待选的克制化候选：其表面较光滑、软渐变较多，描边与装甲分面不如正式舰图/R5 建筑清楚，不称已完全匹配项目美术。**先等待用户对当前候选的选择，不据此另启作图。

| 状态 | ImageGen 原图 | 1440×900 固定宿主配合图 |
|---|---|---|
| 四系统 | [原图](reactor-four-raw.png) | [整屏](reactor-four-host-layout.png) |
| 三系统 | [原图](reactor-three-raw.png) | [整屏](reactor-three-host-layout.png) |

四系统原生 1233×1275 PNG 为 ImageGen 输出 `exec-dc5c3bb1-a313-4480-bedc-bd3671c6d406.png`，SHA256 `358bf569677cdd9c8249b82076121ed4560d94753c43fdf4c435c5470901035a`；三系统图从四系统稿编辑，移除右下凝聚接口、直接读控和短接/通舰管路，并续接正常舱壁与地板，输出 `exec-7217c779-ab58-4bfe-a8cf-1f435c595836.png`，SHA256 `95e6e2f23ce8d3167504baf55ad27afb5104a63eafd45da7fb65f53514fa6bef`。原图未拼贴或后补字。

仍按 [`4f4d63d5` 固定范围](https://github.com/rlmclmc2-boop/space_idle/blob/4f4d63d57ddc215453993cce739eaa3eecfc4198/space-battleship/docs/ui-redesign-plan/shared-host-shell/reactor-drawing-v1/README.md)作图：内容 808×835，宿主偏移 (0,65)，安全内区 (16,16,776,803)。`compose-host.sh` 等比按宽 808 缩放并居中裁少量纯环境，放入 [`shared-host-reference.png`](shared-host-reference.png)；三、四系统整屏图与模板的顶部 1440×65、右战场 632×900 区域逐像素 AE 均为 0。这是静态整屏配合图，不是 Godot 截图。

本轮只供审美术匹配与整体空间。图中核心工作光、端口亮度、滑杆及主控均烘焙在概念图；未实测四路读控 176×112、安全滑杆命中区 132×32、长金额/反馈或动态分层。方向获确认后再制作无字分层和安装锚点。本提交不改 Godot、公共宿主、战场、业务或 `main`。
