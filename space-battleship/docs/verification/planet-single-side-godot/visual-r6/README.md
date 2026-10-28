# 星球 R6：已认可 R5 轮廓的可动模型与实际附着候选（待视觉审查）

本候选从 [R5 四设施简化设计](../visual-r5/README.md)接续。用户认可四张新造型，要求具体工作部件持续运动，并指出旧建筑贴地错误；用户进一步确认：**工坊附着地表随球转，船坞在空间站轨道外侧的独立服务位**。空间站绕轨与资源精炼厂地表归属此前已定。本轮没有更换六星球贴图、业务、经度接缝 shader、共享宿主或 `main.gd`，也没有将 imagegen 合成图冒称运行图。新 GLB、Blender 来源及脚本是**实施候选**；用户尚未审查本轮真实模型画面。

## 实际游戏图与连续视频

官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、`1440×900` 正式主场景，Xorg `:91` 与 Mesa llvmpipe 软件渲染。始源星夹具经真实 GameSession 放开/建好四设施并正常推进时间，完整运行 [驱动](evidence/motion-driver.gd.txt)、[日志](evidence/motion-runtime.txt)和 [原始逐帧轨迹](evidence/motion.jsonl)均归档。合成状态只用于看到已建建筑，不能证明自然建设流程；正常时钟、星球转动和战斗持续运行，没有引擎限帧或强推时钟。

- [完整连续工作与绕轨视频](evidence/full-orbit-working.mp4)：355 张实际帧按 2fps 编码，播放长 `177.5s`。实测地表相位累计 `1.0523546` 圈，采样墙钟 `181.044s`，截图写入成本 `16.891s`；视频时长不等同引擎耗时，详见 [摘要](evidence/motion-summary.json)。
- [30秒起始工作短片](evidence/short-working-00-59.mp4) · [30秒站坞最近段](evidence/short-station-shipyard-155-214.mp4)。片段仍连续取自同一次运行；2fps 只代表归档采样率，不是游戏帧率。
- 原始完整画面静帧：[起始](evidence/keys/key_0000.png)、[球缘转入](evidence/keys/key_0041.png)、[背面隐藏](evidence/keys/key_0125.png)、[站轨前后](evidence/keys/key_0167.png)、[再次显现](evidence/keys/key_0252.png)、[四设施前面](evidence/keys/key_0295.png)、[接近完整圈](evidence/keys/key_0337.png)、[第354帧原始 JPG](evidence/keys/frame_0354.jpg)。其它关键原图也在 `evidence/keys/`。
- 六星球各一张**已建四设施**静帧：[1](evidence/six-built/planet-1.png) · [2](evidence/six-built/planet-2.png) · [3](evidence/six-built/planet-3.png) · [4](evidence/six-built/planet-4.png) · [5](evidence/six-built/planet-5.png) · [6](evidence/six-built/planet-6.png)。[单帧夹具](evidence/six-built/driver.gd.txt)及[运行日志](evidence/six-built/runtime.txt)说明来源；只证明该机位当次静态呈现。特别是白矮星/脉冲星主体和设施都很小，仍需用户观察是否足够辨认，不能用始源星的完整圈代替它们的动态检查。

## 模型、工作部件和附着

[可编辑 Blender/GLB 来源](../../../../art_sources/planet_facilities_v5/build.py)生成四座以暖象牙大装甲、深蓝支架、少量青/琥珀件组织的模型，输出见 `assets/planets/facilities_v5/`。对应 R5 是**轮廓与配色方向**，并非从图中直接提取几何。可动部件不是整栋浮动：空间站居住环转动、两翼摆；精炼厂双入料轮相向转、散热板开合；工坊龙门平移、工具臂摆；船坞吊机平移、泊位环转。[逐帧部件变换与分析](evidence/analysis.json)显示所有预定枢轴在正常运行中改变。

精炼厂/工坊现在采用固定地貌 UV 锚点，按地表相位旋转同一经纬坐标、按解析椭球法线竖立在切平面，足座轻压入表面，接触影投到椭球表面。两者不按云相位移动，也不始终朝镜头。始源星完整采样中两锚点的根节点球心距均为 `2.945`（球面半径 `3`，压入 `0.055`），回算的经度加地表相位在浮点容差内恒定；连续原图显示从前侧到球缘，再由背面遮挡并重新显现。实际外观仍应由用户审图，不能用这两个数值替代“贴得自然”的判断。

船坞固定在站轨外侧右下服务位，给了独立后方深度。始源星本次 355 样本中，递归收集的站/坞屏幕模型 AABB **0 帧相交**、最近包围盒间隙 `42.74px`；三维中心最小距离 `3.635` 场景单位，计算见 [分析数据](evidence/analysis.json)。AABB 与中心距是支持资料，实际视觉前后/净空仍须结合连续视频评审；不把这些数字泛化到全部六颗星或不同宿主画布。右侧战斗与星球在本证据中仍是旧 `main.gd` 外框。

## H1 宿主安装边界

定向对照 `design/shared-host-shell@dfe43cbf` 的 `runtime-h1/README.md` 后，本组仅在 `src/ui/planet_panel.gd` 补 `set_shared_host`、`has_exclusive_ui`、`exclusive_ui_changed`、`prepare_host_hide` 四个最小呈现端口：共享顶部时隐藏本地品牌/钱包，内容根仍保留 `808×900` 内部坐标；原生选择菜单占用、强制隐藏及焦点释放由模块负责。[端口实际探针](evidence/host-port-driver.gd.txt) / [日志](evidence/host-port-runtime.txt)证明在旧主场景中端口状态切换及弹层门禁；[入口脚本检查](evidence/script-check.txt)通过。

**真实 H1 安装仍归整体组。** H1 目前经旧 `_create_bridge_page`/VBox 路由星球，仅装备与反应炉直接 `register_route`；整体组须以现有星球 Control 直接注册替换旧占位并核 `(0,0)/808×900` 画布。这里没有改 H1 宿主、导航或 main，也没有 H1 整屏实测，不宣称 65px 顶部/全局路由已通过。此缺口与 R6 模型运动证据分列，不让宿主未接阻断本组候选交审。

本轮验证限于所列机位与环境。软件渲染采样成本不推断用户 GPU 或高帧性能；六星球完整周期、真实 H1 宿主整屏、全 M7/V7 与用户画面验收均尚未完成。证据文件校验见 [SHA256SUMS](SHA256SUMS)。
