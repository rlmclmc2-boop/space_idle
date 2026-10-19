# player-hull-alignment-20261019
目标：修正五档全部15个挂点，按底座中心与静态安装座贴合验收，覆盖静止及转向前后。
基准：5942d9ee；沿用 art/player-hull-static-five-tiers 分支。禁止改玩法/中心判定，不编译原生组件。
精确定位：presented_ship_view.gd::_fit_approved_weapon_mounts、logical_fleet_pose.gd::_mount、ship_geometry_convention.gd、split_hulls.py 的 POINTS、四个 weapon GLB 的 RotationBearing/TurretPivot、五舰 weapon mount 父变换。
缺口与扩读：为查底座漂移，读取对应模型节点/网格包围盒及其父变换；仅相关测试、现有图形环境配置与自身此前证据。
风险：显示与逻辑炮口可能自洽但同时相对静态图错位，必须加入独立像素安装座和实际底座中心测量。
下一动作：逐挂点检查归一化/镜像/旋转轴链，修复后直接渲染各档静止/转向图和独立误差表。

结果：根因是 apply_direct_fire_alignment 平移 TurretPivot，不是静态坐标错误。取消平移并恢复导入原始轴心。新独立原图像素/实际UV/真实底座网格检查覆盖15点×6状态，修复前36/90失败、最大76.118233px，修复后90/90通过、最大0.000338801px；旧几何专项仍通过。五档各有静止及左右60度局部实渲染和标记图。证据 evidence/fleet-mount-alignment-20261019；旧证据已标否决。未编译或改动原生组件，未改船中心/碰撞/数值；4.7整场回归仍缺环境。
