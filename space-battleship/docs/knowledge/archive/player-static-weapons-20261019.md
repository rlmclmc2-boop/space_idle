# player-static-weapons-20261019
目标：在0bda17f2上接续四种静态新炮台与脉冲光弹的视觉适配；供用户看新舰体上的静止、转向、开火，不合main。
范围与禁止项：复用已修正的安装座/旋转轴；保持射速、弹速、伤害和命中逻辑；不重编原生组件；等待父提供透明资产Git路径。
精确定位：scripts/presented_ship_view.gd:set_loadout/_fit_approved_weapon_mounts/apply_direct_fire_alignment；scripts/logical_fleet_pose.gd:prepare/_mount；dev/toon_ship/pulse_vfx.gd:flight/flash；scripts/battlefield.gd的PULSE_VFX调用及脉冲保留GPU呈现入口。
缺口/扩读：限定查找PULSE_VFX.flight调用者、pulse projectile视觉与GPU网格构建符号，确认真实运行路径，避免仅改未使用fallback。
已知风险：静态炮台透明边距/底座中心/炮口必须与已有旋转轴一致；脉冲光弹可能有独立GPU路径，不能借视觉改弹体逻辑。
下一动作：回报最小贴图入口，等待父资产路径。

资产 c59db375 已收到并查看。四炮台按主体连通域拆分；原始底座中心及视觉比例显式记录。保持旧RotationBearing/TurretPivot/Muzzle节点与变换，用新PlaneMesh仅替换可见网格。脉冲CPU flight改贴图；GPU retained材质复用原生脉冲拓扑首6顶点的quad，其余旧菱形/横纹三角形折叠，沿用原生实例方向/时钟/速度，不改C++。扩读：验证首6顶点索引来源只需 native combat_presentation.h:prepare_pulse_mesh 与 combat_retained_presentation.h:prepare_retained_mesh；只检查既有line/tri生成的索引顺序。

交付：新四炮台与脉冲贴图完成视觉接入；原炮口/旋转轴/配置/逻辑/原生源码无变化。四武器静止/转向/开火预览和五档局部实渲染位于 evidence/static-weapons-20261019。90点状态贴合通过；贴图口对真实炮口最大误差.032166px；CPU/GPU光弹逐像素RGBA误差0，时钟/速度8px位移检查通过。正式4.7原生整场未执行，本轮供先看效果。
