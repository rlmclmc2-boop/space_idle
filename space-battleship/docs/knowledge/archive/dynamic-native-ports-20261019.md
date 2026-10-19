# dynamic-native-ports-20261019
基准c4a5e259，独立分支沿用。目标：配置/挂点/缩放动态生成视觉炮口；原生GPU出生固定视觉起点，后续转向不拖动旧弹；保留批次，不每帧逐弹GDS或重建；不改数值弹道/伤害。用户已允许原生呈现源码修改与重编，不合main。
范围：GDS显示口描述发布、原生presentation出生快照、配套构建、接口正确性及既有统一高负载前后对照。正式4.7/Windows环境若无则明确测量缺口，不用低负载替代。
定位：native_execution_session.prepare_geometry、battle_slice_runtime、combat_presentation.h、combat_retained_presentation.h；必要只读kernel出生/回收和screen字段。性能扩读只定位统一高负载样本文件、驱动与冻结输入；不跨任务状态。
下一步：确认出生时可用的显示配置接口及负载样本，建立配置发布/出生快照，不在每帧回调逐弹。

交付：独立presentation_muzzles输入；logical_fleet_pose按当前挂点/轴/weapon_scale和静态武器anchor/emission/visual_scale投影，session按挂点发布变化。kernel在实际birth冻结显示origin/step，retained只读显示副本；数值ray/碰撞/伤害/RNG字段未改。紧缩事件复制独立显示字段到事件层，旧弹不读后续炮口。GPU12float协议/时钟/保留mesh不变；无逐弹GDS帧循环。
验证：专用接口5571项0失败；675投影点最大误差0.00006824px，覆盖五档四族、挂点/发射像素/贴图及挂点缩放；同库SHA在改配置前后不变。8组各300精确步数值/RNG/伤害一致；四族均实际结算伤害。出生前首次显示、显示后、退休及槽复用快照、非法输入及空行fallback均检查。现有kernel485、数值边界54、挂点90样本通过。旧geometry_scale测试未完成：既有观察器无条件读shot，不接受compact反馈，headless又无法完成postdraw等待；未计通过。
构建：基线/candidate Linux4.6.3 .so均编译成功；证据builds内含配套包、源码/API/二进制hash、构建日志；新增Linux构建脚本，正式Windows脚本不变。Windows4.7.2/API及工具链缺失，所以正式DLL构建待支持环境执行，非权限拒绝。
性能：原冻结统一高负载mixed/laser/cannon/missile/longLaser五组before/after全部运行，原15敌人/强化40/五无人机/240热身480采样目标/完整墙钟四分段保留；mixed在其他检查退出后复测，交付仅串行复测。所有candidate原生入场、0脚本错误、old_advance0。每一对均至少一侧未通过严格步数或1x门槛，Linux llvmpipe不替代Windows物理GPU性能验收；原始JSON、门槛、分段与缺口完整保留，无低负载替代。
文档及证据：addons/native_battle/README.dynamic-ports.md，test/evidence/dynamic-native-ports-20261019。没有新美术、没有扩截图矩阵，没有合main。父审后需在支持环境补正式Windows DLL及统一样本性能验收。
