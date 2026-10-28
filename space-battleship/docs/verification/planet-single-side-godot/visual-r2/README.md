# 星球视觉修订 R2（待独审）

`35d27587` 已被根审判定视觉不通过，原 4.6.3 证据保留为业务绑定和失败画面的历史，不能作为获批方案的正式交付。本轮保留已认可的同星球绑定、ready→built 和探索/施工语义，只修视觉、真实菜单输入、重铸可见落点及补人后的实际推进。

实际变更：默认球改用新 imagegen 地表/独立云密度和柔和大气光照；建筑改用第三版分件几何与共享材质图集；场景中心略向右安排以保留球体大小，设施入口与 276px 左侧抽屉共用 x=22 锚点，删除实际不可见的连线。探索详情重复名称/探索度已合并；详情签名只含当前星球人员，其他星球人员变化不再因整份 Crew 视图改变而重建当前设施详情。业务状态和后端契约未重写。

环境已切换到官方 Godot `4.7.2.stable.official.ed1daf0bf`。其导出 API SHA-256 为 `d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`，与项目 `build_native.ps1` 的固定值完全一致；native 使用原指定 godot-cpp 提交及同一 API 重建。Linux 验证库使用动态 C++ 运行库，临时构建目录不交付。Windows 工具链和用户 GPU 仍未测试。

真实输入使用 Xorg :91 上的 XTest 系统鼠标，经 Godot 实际 OptionButton/PopupMenu 打开并点击行；不再调用 `select` 或 `item_selected.emit`。记录包括实际菜单画面、行坐标、窗口 ID、选择后同一星球事实。此环境的 PopupMenu 为 Godot 嵌入子窗（window_id=0），不冒称单独原生 OS 窗口或完整键盘验收。补施工者后恢复 Session 推进，必须观察 shipyard work 从1增长到至少2，并记录真实 D/任务时钟。

重铸区域在原星图页移到首位，导航落点回到该页顶部；真实画面必须同时看到标题、当前星球选择器及预览/确认/取消按钮，仍不自动执行重铸。隐藏 ID 相等仅作辅助断言。

同一 4.7.2 主场景可切换装备/反应堆/星球；当前固定宿主仍为 `170849dd`，反应堆实际显示“供能状态暂不可用”，这是原组未完成匹配接口的边界，本组未修改其代码，不能把加载/导航证据称为三模块完整接入验收。

累计 Buff 详情继续明确未完成。最小缺口已列在 [Buff 只读缺口](buff-readonly-gap.md)，本组不自行新增后端出口或从配置/私有缓存另算。原独审及用户仍须判断新的球面、建筑和抽屉品质。

## 固定运行证据

代码检查点 `ef774207`，客户区1440×900、星球模块808×900。所有 PNG 为同一 4.7.2 主场景原始输出，无裁切/拼接/额外压缩；本轮 imagegen 原图也逐字节核对，未后处理。资源、脚本、引擎/native/API 及证据 SHA-256 见 [manifest.json](manifest.json)。源和提示词见[球面资源](../../../../assets/planets/painted-v3/README.md)、[建筑资源](../../../../assets/planets/facilities_v3/README.md)。

| 核对 | 真实画面 |
|---|---|
| 球面/建筑与左侧展开 | [01 默认](evidence/01-default-planet1.png)、[02 展开](evidence/02-facilities-planet1-ready.png)、[05 领取后](evidence/05-planet1-claimed.png) |
| 原生控件实际选择 | [星球菜单](evidence/native-planet-popup.png)、[设施菜单](evidence/native-facility-popup.png)、[人员菜单](evidence/native-crew-popup.png)；系统鼠标共7次菜单行选择，见操作记录 |
| 展开中切球及切回 | [03 第二星球施工2/5](evidence/03-same-drawer-planet2-building.png)、[04 切回第一星球待领](evidence/04-switch-back-planet1-ready.png) |
| 自动设置和取消 | [06 关闭自动但本次继续](evidence/06-stop-after-current.png)、[07 立即取消](evidence/07-cancelled.png)，保留另一个星球运行/人员的断言 |
| 独立内容层级 | [08 人员](evidence/08-crew-section.png)、[09 探索](evidence/09-exploration-section.png)，名称/探索度在抽屉内各显示一次 |
| 同机位持续动态 | [10 t0](evidence/10-motion-t0-all-built.png)、[11 t4](evidence/11-motion-t4-all-built.png)、[12 t8](evidence/12-motion-t8-all-built.png)；1×、人员在岗、未暂停，t标记为近似墙钟，真实时钟/相位见记录 |
| 重铸可见落点 | [13](evidence/13-existing-reforge-context.png) 同时显示“重铸远征”、同一始源星选择器及预览/确认/取消，未执行重铸 |
| 补人和实际施工增长 | [14 缺人](evidence/14-missing-builder.png)→[15 已补人](evidence/15-builder-assigned.png)→[16 实际增长](evidence/16-construction-actually-progressed.png)：额外人员0/1→1/1，船坞1/10→2/10，D151→D152 |
| 同一进程/引擎的导航边界 | [17 反应堆](evidence/17-shared-host-reactor.png)、[18 装备](evidence/18-shared-host-equipment.png)；17明确显示供能数据不可用，不记其他模块验收 |

[操作/快照](evidence/operations.json)、[驱动](evidence/fixture-driver.gd.txt)、[系统鼠标辅助](evidence/os-input.py.txt)、[原始运行日志](evidence/runtime.txt)、[脚本检查](evidence/script-check.txt)、[native 构建清单](evidence/native-build-manifest.json)可复查。最终轮无脚本/运行错误；VSync设置不受 llvmpipe 支持的警告保留，不声称已控制用户设备 VSync。

起始状态继续使用前轮明确的公开恢复夹具：战役开放 grants；第一星球D240已征服且精炼厂ready，第二星球D22精炼厂2/5；经真实协调派遣与贡献发布接纳。14–16另构造第二星球D151船坞1/10，然后由真实 UI 补人并恢复 Session 帧推进。固定起点的01–09停止宿主推进以防截取漂移，局部展示仍运行；10–13与16恢复真实推进。夹具不证明自然开放、征服或长期流程。

本轮未增加帧帽，没有执行可见网格球B、CPU/GPU基准或全周期运动包络验收。新材质/纹理和模型的成本未测，不能把软件渲染时钟或静帧外推用户 GPU。当前仅为供原独审/用户判断的修订候选，不宣称 M7 完整或视觉通过。
