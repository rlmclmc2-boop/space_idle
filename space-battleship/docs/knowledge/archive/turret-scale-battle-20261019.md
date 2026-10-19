# turret-scale-battle-20261019
基准97990c6e，沿原独立分支。目标：扩大四种炮台主体，充分利用安装座空间；五档全部原尺寸可辨识与转向遮挡需以同窗口完整战场截图复核，不能局部放大代替。
限制：只视觉，数值射速/弹速/伤害/命中不改；不重编原生。现有环境仅4.6.3，无4.7/DLL可用，需先核查完整main.tscn的GDS fallback是否可运行。原局部图不可视作战场验证。
定位：presented_ship_view.gd::_install_static_weapon_art/视觉炮口；battlefield.gd::visual_muzzle/_prototype_launch_pose/weapon_launch；原完整战场capture脚本的场景装配与保存隔离片段；game.gd::admit_native_compiled_execution 仅查fallback可用性。
下一步：隔离导入并先跑完整战场；检查能否真实开火/命中，明确环境缺口后调整显示尺度与视觉炮口。

交付：四炮台放大并保留源图比例，新增独立VisualPort，原数值炮口与磁轨数值几何保持。20组真实main.tscn GDS回退均开火/命中，20普通+40左右60度完整PNG全部1372×883；证据evidence/turret-scale-battle-20261019。90次实际图像基座贴合及480相邻底座中心遮挡检查通过，原数值炮口专项通过。未构建/改动原生或战斗逻辑；正式4.7原生GPU视觉炮口映射仍缺验证及必要适配，不能宣称原生整场已通过。
