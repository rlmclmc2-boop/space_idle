# R16 实体脊梁与设施台座返修

此候选接续 [R15 实机接入](../visual-r15-orbital-spine/README.md)；R15 的平色环和视频是修前历史，不可当本版视觉证据。用户认可的结构参照仍是[固态完整态概念](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)与[闭环五态概念](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)。R16 源码只修改 `scripts/planet_orbital_spine.gd`、`scripts/planet_facility_scene.gd` 和 `scripts/planet_visual.gd`；没有改建筑规则、宿主、装备或 main。

R15 的环是单层平色条，设施卡片与带面共锚深度，导致旧视频 43/51 的精炼厂和 87 的工坊正面被环贯穿；旧画面中心在模块宽度 0.57，站翼在 51 裁边，气态/红巨静帧工坊贴边。R16 把四个自带弧段改成同轨道平面的连续深青厚脊梁、侧壁、暖象牙装甲大板和细青色通道；每座已建设施同时带来加宽鞍座、装甲平台和承力轴座。建筑落在轴座上方，随环移动时保持朝向。相邻两座均已建时才出现段间实体接头；未建段与未来平台仍不出现。球后仍由真实网格与深度遮挡形成，不烘焙断口。环、球、探索船沿用各自原时钟。

[主界面阶段 1、3、4](evidence/full-ui/)来自 1440×900 `main.gd` 真界面、既有恢复端口设置的临时第一星球 `built` 集合；作者原尺寸目视。第 4 阶段可以直接比较建筑与台座、前弧截面和闭环；第 1、3 阶段检查独立段自带支撑与开放端。金币/探索度是夹具状态。完整夹具见[driver.gd.txt](evidence/full-ui/driver.gd.txt)。

[新码动态视频](evidence/phases/orbit-one-revolution.mp4)由 Godot 4.7.2 真渲染 97 帧组成，按每帧约 1.454 秒模拟时钟采样一圈，再以 8 帧/秒合成 12.125 秒供审图；这不是墙钟帧率或性能测量。作者以原尺寸复核[首尾和重点相位](evidence/phases/)的 0、24、43、51、72、87、96 帧：旧问题相位设施正面不再被带贯穿，段间接头可见，站翼没有裁到模块边界，背侧遮挡仍由球体产生。对本次 97 张采样画面作辅助边缘扫描，亮色主体离模块左右边缘至少约 26/31 像素；该像素阈值只是裁边辅助检查，视觉结论以原画面为准。源夹具见[driver.gd.txt](evidence/phases/driver.gd.txt)。

[气态与红巨星](evidence/celestial/)采用现有配置外观与同一个共用环带，复核了先前被指出的工坊边界问题；本轮不把二者宣称为专属美术完成。Godot `--check-only`、主界面/动态/类别夹具均退出码 0；日志在各证据子目录，ALSA 缺设备后使用 dummy audio，不影响画面。`git diff --check` 通过。全部 PNG/MP4 的 SHA-256 在[evidence/sha256.txt](evidence/sha256.txt)。仍待原 Astra 对新的视觉层次和多相位画面审查。
