# player-hull-static-20261019
目标：导入父线程提供的五档透明底静态舰体，独立炮台挂接 1/2/3/4/5 槽，保留船中心判定。
范围与禁止项：只替换我方舰体呈现及必要挂点；不程序重画舰体，不改玩法、数值、存档或敌方。
基准：origin/main 8ff9a7bd。分支 art/player-hull-static-five-tiers。
停止条件：缺少已定稿资产时先回报接入口并等待；父审后才合并 main。
精确定位：scripts/ship_visuals.gd、scripts/presented_ship_view.gd、scripts/flat_ship_compositor.gd、data/ship_weapon_visuals.json、assets/ui/ships/manifest.json。
已知风险：静态舰体与既有旋转炮台的坐标/大小映射必须一致。
下一动作：核对以上目标的贴图入口、五档大小及挂点符号，等待父线程资产路径。
扩读缺口：为定位具体入口，限定搜索 scripts 中 ship texture/hardpoint 符号；只读其命中范围。

核对结果：战斗贴图与归一化挂点统一位于 data/ship_weapon_visuals.json 的前五个 ships 条目；菜单贴图入口 assets/ui/ships/manifest.json。现有五张战斗图均 887×1774。display_scale 依次 .061/.093/.081/.093/.12，项目 visuals/player_ship_scale=1.7，额外显示配置仍沿用。槽数 1/2/3/4/5，旋转限制 75/80/80/75/75 度。主呈现脚本 _install_approved_hull_art 目前限定 approved_fleet_20261018/player 路径，若新目录需同步调整。logical_fleet_pose.gd 从同一贴图/挂点推导真实炮口，必须用现有 verify_player_hardpoint_geometry.gd 校核。geometry_texture 保留旧图以维护现有船中心和判定。最小证据复用 test/capture_player_hardpoints.gd（五档满武器）与 test/verify_player_hardpoint_geometry.gd；必要时 capture_battle_hardpoints.gd。Godot 可用。
当前状态：接入核对完成；尚未替换资产或运行游戏检查，等待父线程 Git 分支/提交及五档资产路径。

2026-10-19 资产收到：abdd8d1d21847e99ce876acaa7426e8275de9994，仅取 art_sources/fleet-20261019 两张源图。透明图 1983×793，阈值 127 可分离五舰；原 alpha>0 存在零散噪点且 3/4 边缘相连，按五个主体连通域及其抗锯齿邻域拆分，清理透明区残留。扩读缺口：为保持显示/逻辑炮口一致，限定 logical_fleet_pose.gd:prepare/approved、battlefield.gd 的 reference_height 计算，以及 test/capture_*hardpoints.gd、verify_player_hardpoint_geometry.gd、docs/TEST.md 相关 Godot 命令。

交付：完成静态舰体及菜单图接入，1–5 槽挂点适配；静态高度来自定稿原图，宽高逐档增加。最小检查及十张实际图位于 evidence/fleet-static-20261019/。全部 15 槽已开火，炮口和船中心判定源沿用。限制：本机 Godot 4.6.3，正式 4.7 待父复核；旧菜单测试有既存八槽硬编码，受影响前段153项通过。下一动作：独立分支提交并推送，父审后合并。
