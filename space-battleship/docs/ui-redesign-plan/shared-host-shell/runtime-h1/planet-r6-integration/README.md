# 星球 R6 × 共享宿主 H1：实际独立场景接入

代码`design/shared-host-shell@8a66007633e2c976ca4527506df34a00020eeca8`，未合main。星球原组固定来源`b185d5ab4e12c3eee9991a329973697f5f793c47`；[原组R6入口/连续动画与限制](https://github.com/rlmclmc2-boop/space_idle/blob/b185d5ab4e12c3eee9991a329973697f5f793c47/space-battleship/docs/verification/planet-single-side-godot/visual-r6/README.md)。本轮原工作区继续，装备仍保留551a4f2b；不另开任务/独立复测。

## 真实装配

`main`创建原PlanetPanel并注入原Planet、取消、领取、命令回调、视觉上下文、Crew与派遣callable，放在层9的(0,0)/808×900，直接`register_route("planet",...,planet_scene)`。旧星球VBox/滚动占位路由已移除；总路由仍15。公共资源栏/导航在层10，占用原0..65；原组set_shared_host退出本地品牌/钱包，context_slot由宿主管理。

24个原组文件逐字节保留：PlanetPanel、Planet领域文件、planet_visual、rotating_planet与shader、设施场景/接触影shader、facilities_v5模型/说明及可编辑来源、painted-v4贴图/导入参数。准确名单、哈希及固定Git来源见[身份/环境记录](evidence/environment.json)。没有替换用户认可的六星球贴图、重写动画/附着或重新实现模块内部。未引入旧facilities_v2/v3/v4或painted-v3。

原组Planet依赖含conquest_facts/conquest_changed及其已有非有限来源校验；该文件同样直接保留b185d5ab，不由宿主重算征服奖励、建筑/任务或贡献。GameSession、Crew、native和生产配置未改。绘制依赖其余原orbital_facilities/planet_art代码在当前基线相同，不重复搬运。

`reforge_requested`只切到既有重铸路由、预选同一星球并聚焦选择器；不自动预览、付款、确认或取消已有事务。重铸预览/确认/取消仍原main事务。星球独占使用原组四个最小端口，其他公共门禁沿装备组合已窄修的被动tooltip判定；战场投影不动。

## 原任务内必要组合观察

[23项记录](evidence/observations.json)全部通过，[实际日志](evidence/godot-live.txt)无脚本/资源错误，只有既有Xorg VSync警告。[Godot4.7.2解析检查](evidence/godot-check.txt)和Git diff检查通过。

先使用新的隔离真实Session验证自然未开放、星球导航拒绝。随后通过原组公开restore_state/refresh_availability临时给予Campaign开放及始源星四设施已建状态，保留正常Session/战斗/视觉时钟；未修改配置/源码或强推时钟。**后段是明确夹具，不证明自然解锁、探索/建设或征服成功。** 夹具保存与个人设置只在/tmp，不入Git。

必要结果：

- 星球是直接808×900场景；公共chrome隐藏、上下文显示、15路由、自然锁定判定和原(855.875,0)/0.9375投影保持。
- 实际鼠标从公共星球入口激活模块。原组模型包含10个预定工作枢轴；短时记录确认部件变换集合和地表相位继续变化（后者由约0.00747到0.01353），未逐部件逐项判定；仅证明宿主没有冻结/替换原动画，不据此批准运动品质、完整圈或六星球动态。
- 真实鼠标打开星球原生下拉，模块prepare_host_hide拒绝普通离页；公共导航、Space/G与右战场鼠标均被阻断。关闭后右战场鼠标恢复，正常Space/G正向对照通过。
- 本地设施抽屉仍能操作；跨装备切换及收起/恢复保持同一星球实例、选择和抽屉状态。隐藏时无用视觉相位停止；force清理原生Popup有效。
- “前往重铸”信号只完成路由与星球预选，pending_reforge前后相同，未触发实际事务。

[真实星球整屏](evidence/planet-full.png) · [稍后动画状态](evidence/planet-motion-later.png) · [原生下拉](evidence/planet-native-popup.png) · [设施抽屉](evidence/planet-facilities.png) · [重铸导航](evidence/reforge-navigation.png)。整屏/下拉/设施图已实际查看；本轮没有重出原组动画视频，根端继续审原R6视频，不用路由通过替代视觉通过。

## 当前边界

装备原组551a4f2b和星球原组b185d5ab现已同时进入共享宿主候选。前者33项证据保留在[装备组合](../equipment-owner-integration/README.md)，其源码本轮未动；本次新增星球23项不冒充购买玩法或全部模块回归。

尚未覆盖自然全建设流程、六星球完整周期、Session导入/重铸成功全链、Windows/DPI及V0；R6模型/附着/动画的视觉批准仍归原审与用户。反应炉新稿继续原组负责。当前无权限/运行阻塞，原模块后续美术不阻断已完成公共接入。
