# 星球集中式方案：Godot 接入候选

已将用户批准的 [e78af05f 图稿](../../ui-redesign-plan/planet-single-side-v5/README.md)接入真实 Godot 主场景，并按用户后续要求重做设施建筑。当前交付供原独审和用户检查，未合 main，未记 V0/V7 或建筑品质验收通过。唯一规范入口仍为[游戏设计 README](../../game-design/README.md)，本模块要求见 [M7](../../game-design/art/modules/planet.md)。

运行代码检查点为 `39b5dba3`，固定宿主依赖为 `170849dd`；精确文件哈希、引擎、native 库及图像见 [manifest.json](manifest.json)。本提交相对宿主的运行改动只涉及星球面板、星球场景/建筑层与宿主最小注册，不修改装备或反应炉实现；依赖分支的既有内容不是本组重新制作或验收的范围。图稿示例 D68、68% 和施工次数均未写死进界面。

## 绑定与逻辑从属

- 全部读取与命令以一个当前星球 ID 为根。顶部选择器、探索任务、人员入口、设施详情和停止/取消均取同一已接纳状态。切球同步清除旧详情/短暂反馈，重选该星球实际适用设施，重新取得领取准入；载入新星体时清除旧建筑。
- “设施”入口持续选中，展开区与其共用横向锚点并有短连接线，面板标题、当前星球、设施选择及收起动作形成子级。探索/人员分别打开自己的内容，设施区不混入探索时间条或全员表。展开不遮停止/取消。
- 本次探索使用 `visual_snapshot.elapsed/duration`，探索度另标；设施使用 `facility_facts.work/required_work/work_fraction`，单位为完成的探索次数。施工暂停原因、当前额外施工人数和领取准入直接读取事实；未领取不显示已生效倍率。
- `Planet.planet_options/visual_snapshot/facility_facts/assignment_options` 与 `Crew.step_assignments/member_options/member_facts` 为读取边界；派遣和取消经过 Session 协调，领取经过 Planet 和既有发布事务。没有 UI 人员账本、施工推进器或 Amount 求值。
- 沿模块已有通知合并可见帧刷新：其他星球单独的计时通知不刷新当前星球；选择器只因开放列表变化重建。普通计时不清空选择器或每帧重建展开区。人员变动重读当帧 Crew 视图。
- 命令复用宿主 `_command_button` 的既有准入；局部结果反馈四秒后收回。船坞已领取时可跳转现有征服/重铸页，并绑定同一星球；只导航，不自行执行或绕过预览/确认/取消。

宿主注册沿 `170849dd` 的 `unlock_kind/unlock_target`：星球使用已有 `planet/1` 开放项，不杜撰 `feature/planet`。导航与显隐仍归宿主；原“星图”纵向页的重复星球面板已移除。三枚导航缩至 80px 并调整起点，避开既有舰桥面板按钮，未整体缩字。左侧 Control 为 808×900，客户区为 1440×900；右侧战场及其原逻辑坐标、居中留边继承宿主。

## 建筑与动态层

新设施资产及可编辑来源见[资产说明](../../../assets/planets/facilities_v2/README.md)。可见球体沿用解析球面、独立云层及固定光照；设施采用新 GLB，在首次出现已领取设施时创建一个共享透明 viewport。不可见的同形球/椭球深度遮罩与建筑深度写入共同处理遮挡。地表建筑跟随同一地表相位、切平面和球缘变化；气态巨星轴比及已有脉动参数也投影到遮罩/贴附位置。空间站绕行，工坊地表和固定近轨船坞仍是设计建议。建筑只供观看，不是交互命中区。

这不是可见网格球 B 路线实现，也不是解析球面/真实网格球的性能比较。新增 viewport、模型和遮罩有实际成本，CPU/GPU 均未测，不能从 llvmpipe 外推用户 GPU。没有新增测试帧帽；保留已有视觉层动画更新节奏。

## 真实运行与起始状态

本地使用 Godot 4.6.3、Xorg dummy 1440×900、OpenGL Compatibility/Mesa llvmpipe；Windows 4.7.2 未运行。native 使用仓库指定 godot-cpp `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`、本机导出 API 构建。默认静态 C++ 运行库版本在初始化时崩溃，本地改为 SCons `use_static_cpp=no` 重链接后主场景启动及操作成功；该变通只在 `/tmp`，未改生产 native/build 脚本。数据/设置/存档均隔离到临时目录，不交付缓存或个人存档。

[复现驱动](evidence/driver.gd.txt)运行正常 `src/main.gd`，使用公开恢复入口构造可审查起点：战役开放 grants；第一星球 D240、已征服，空间站/工坊/船坞已领取、精炼厂 ready；第二星球 D22，空间站已领取、精炼厂施工 2/5。两位探索者经真实协调端口派遣；初始本次时钟分别为 24/60 秒、8/约43.9秒。期间贡献经既有发布事务接纳。这些是显式夹具状态，不证明自然到达/开放/征服流程。

14–15 另用公开恢复入口构造第二星球 D151、船坞施工 1/10 的缺人场景，并再次通过现有贡献发布事务接纳；随后经人员入口补一位额外施工者。该补充同样不是自然游玩到达证据。

01–09 为固定起点的对象/命令验证，宿主推进暂时停止以排除截取漂移，局部展示仍运行；不能把这些截图当持续推进录像。10–12 重新通过人员与探索入口派遣并开启自动，恢复真实 Session 帧推进，探索者持续在岗、1×、未暂停；文件名 t0/t4/t8 为近似墙钟间隔，真实 game_time/elapsed/相位均记录在 [operations.json](evidence/operations.json)，不冒称精确游戏秒。

| 图 | 实际内容 |
|---|---|
| [01 默认](evidence/01-default-planet1.png) | 第一星球 D240；本次 24/60 秒，40%；待领入口可发现 |
| [02 展开](evidence/02-facilities-planet1-ready.png) | 设施入口选中、子级管理区、同一星球精炼厂 ready |
| [03 展开中切球](evidence/03-same-drawer-planet2-building.png) | 第二星球 D22；本次 8/约43.9 秒，18%；精炼厂施工 2/5，40%，两种进度明确区分 |
| [04 切回](evidence/04-switch-back-planet1-ready.png) | 恢复第一星球的 ready 与本次探索状态，不携带第二星球施工读数 |
| [05 领取后](evidence/05-planet1-claimed.png) | 真实领取接纳后 built、来源因子和新地表建筑出现 |
| [06 停止自动](evidence/06-stop-after-current.png) | automatic=false，当前任务仍 running |
| [07 立即取消](evidence/07-cancelled.png) | 第一星球任务停止并释放探索者；断言第二星球仍在运行且人员不变 |
| [08 人员](evidence/08-crew-section.png) / [09 探索](evidence/09-exploration-section.png) | 两个入口各自的内容，未混入设施表 |
| [10 t0](evidence/10-motion-t0-all-built.png) / [11 t4](evidence/11-motion-t4-all-built.png) / [12 t8](evidence/12-motion-t8-all-built.png) | 领取后的同一场景，重新派遣并开启自动；地表、云与站体持续变化，固定光向及地表关系保持 |
| [13 重铸上下文](evidence/13-existing-reforge-context.png) | 只进入既有预览页，星球选择仍为同一 ID，未执行重铸 |
| [14 缺施工人](evidence/14-missing-builder.png) / [15 补人后](evidence/15-builder-assigned.png) | 同一第二星球船坞 1/10，额外人员从0/1到1/1，MissingBuilders清除；顶部人数从1到2，包含探索者与施工者 |

## 检查范围与未闭合项

脚本编译、真实主场景启动、Godot 鼠标输入事件路由、上述业务断言和对象隔离已执行。原生弹出菜单跨窗口键盘注入在当前 Xorg 下未稳定工作；切星/设施菜单项使用 OptionButton 的公开选择信号驱动，不能记为完整弹出菜单键盘/鼠标验收。最后一轮原始运行日志见 [runtime.log](evidence/runtime.log)，不将先前失败探针或旧画面混作最终通过记录。

当前只覆盖桌面目标及短时动态，完整站体/抵达运动包络、所有星体的设施分布、长时运行、Windows 与用户硬件仍待审。累计征服 Buff 的独立结构化展示出口不在现有已审事实内，本轮不从 Planet 私有账本/配置另算；现有重铸流程及单设施来源因子保持，累计 Buff 详情仍是展示缺口。建筑造型/材质仍交原独审和用户判断，不以重新导出模型或静态编译代替品质确认。
