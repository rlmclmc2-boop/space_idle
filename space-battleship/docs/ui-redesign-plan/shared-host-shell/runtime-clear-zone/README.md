# 公共壳与 R3：当前制作入口

## 当前目标

用户已认可 R3 的共同材质方向，授权公共区域与原生控件在游戏内推进；各模块内部、完整操作、性能及整组品质须按当前版本另审。制作以[13§2.4 可见内容区与整页布局约束](../../../game-design/13-art-interaction.md#24-制作前的布局约束与整页校验)为准；字体/资源/数量与费用语义依[13](../../../game-design/13-art-interaction.md)、[14](../../../game-design/14-ui-contracts.md)及[资源契约](../../../game-design/contracts/resources.md)。原生图标按身份读取透明资产，不从整屏截图截取矩形图块。

## 固定运行基线与公共契约

- 当前可撤回共享组合运行源码 `design/clear-zone-host@94fb201916792ca2b3b4677cdb43dbfd6e499fad` 已在 R12 闭包上同步 `f7d3d055` 炉池下降槽的四件固定修改；其余沿用基础 R12 `0bc17ae48107972c88a84069cf5221bf5c1cbb0f` 的原接入闭包。旧 `3504a52d` 视觉判断被用户否决，只保留于独立归档，不再预载其旧反应堆绘制路径、复用旧图或作为本版验收依据；已退役资产暂留仓库，避免误删其他引用。
- 已合主线装备以 `main@e845ca58afd39184c3d4c5743021480e393adf74` 为运行事实；公共壳保留本分支 `main.gd`、`ZoneShell`、`BridgeTheme`、`PlayerText.resource_number`、资源身份、导航按住字图状态 `0049ed4c`。不以模块分支旧 main/theme 覆盖公共层。星球当前旧内区仅供路由返回，不代表已获品质认可。
- 公共操作材质由现有 `BridgeTheme.operation_plate/operation_button/apply_operation_button/apply_operation_select` 及 `control-materials.png`、`stepper-down.svg` 提供；原生节点替换旧绘制面，不叠新底板或重复控件。数量键循环 ×1→×10→MAX 只更新报价/可购买状态，执行键才提交；后台余额、费用与支付遵整数资源契约，UI 不自行 `ceil`。
- 1440×900 下模块为 `x=0..808`、顶轨下内容从 `y=65` 接续；导航为 `x=808..855.875`，战斗有效投影为 `x=855.875..1392.125`、scale 0.9375。公共宿主负责顶带退出、显隐、焦点、导航与资源，保持战斗主体和输入契约。真实文字墨迹、图标、控件边光与模块实体均须在可见承载面内留出净空，按完整整屏及相关动态判断；代码尺寸或元素存在不能替代视觉检查。

## 反应堆重做的当前接口

用户已要求原反应堆组重做，旧机械环/连接坐标不构成新方案约束。每个设备的独立 asset 先固定管道接口**同一坐标及朝向**，再由原组按该端点精确拼接；核心不保留上下铁架，设备水波效果退役。均分按钮不得越出金色凹槽实绘下边，单路标签、滑条和数值须在完整操作区中构成清楚的一组。原组负责内部 asset、端点、方向及可动/不可动层并交固定运行源；本组负责精确接入、公共边界与同版跨页整体判断，不代画内部或拿旧坐标阻新设计。验收须亲看实体接口真正连续、操作组在真实边界内，不能以可读、已出现或朝向近似替代。

## 下一交接与未覆盖

### R12 已接源码与同壳作者证据（WIP）

原组文本入口 `implement/reactor-centered-godot@749eccd11d6a6c67a91f9a7138c03508481d373c` 指向运行源 **`0bc17ae48107972c88a84069cf5221bf5c1cbb0f`**；同源 `reactor_ports.json` 是设备/管路/Godot 的统一端口契约。对照当前旧 R5f `c0add846f2db273d0418d04077739de23093b981` 的[精确文件差异](https://github.com/rlmclmc2-boop/space_idle/compare/c0add846f2db273d0418d04077739de23093b981...0bc17ae48107972c88a84069cf5221bf5c1cbb0f)，必要生产源码仅 `src/ui/reactor_scene.gd`、`reactor_stage.gd`、`reactor_module_view.gd`、`reactor_pipe_view.gd` 四处修改及新增 `src/ui/reactor_port_contract.gd`；并取 `assets/ui/reactor/b01/reactor_ports.json`。`reactor_scene` 仍用原 `_init(owner, inputs, payment, publish, can_pay)`、`bind_presentation`、`bind_purchase_quote`，舞台仍为 808×835；`reactor_stage`、设备视图和管视图通过同一 PortContract 读取源裁区、接口和路径。R12 对比没有 Owner、`main.gd`、`BridgeTheme`、`ZoneShell`、`PlayerText` 或公共资源接口生产差异；本次均保留本组层及 e845 装备、星球和战斗空间。五处源码及端口 JSON 在固定提交中与 R12 原 blob 一致。

运行资产增改闭包位于同一 `assets/ui/reactor/b01/`：四机 `r6-{weapons,defence,smelting,condensation}.png` 与对应 `-work.png`、`r6-defence-front.png`；四路 `modular-pipe-{weapons,defence,smelting,condensation}-{shell,front,insert}.png`；`modular-core-field.gdshader`、`modular-module-work.gdshader` 与新 `modular-shield-front-glow.gdshader`。原场景仍预载同目录 bay/core/core-work、compact/four console、core clamps、gimbal `*-00`、pipe lumen shader 与控制图集/滑条等未改资源，须保留。新源不再引用旧 active/idle/locked console、旧 `modular-{四机}` 基图/工作图、旧 mask/整图及 gimbal `01..11` 等退役件；本次运行源码已改为 R12 预载，旧件未随本窄接删除；清理须另核全仓真实引用。端口 JSON `e57762402b846c142b93d85a8a2264f03be222fa` 与武器基图 `d6830b7fc2e4448f036ad956f1e11e79b4839589` 等 30 件均按源 blob 精确取入，本次未另改模块内部设计。

**接入事实：**Godot 4.7.2 在可写 `/tmp` XDG 目录下导入和 `src/main.gd --check-only` 均退出 0、无解析/资源错误；原生主入口同版 1440×900 的最终装备、R12 四路零态、受控单路真零与切回装备四张整屏已实际生成并由作者看全幅。短视频从该固定源码单独进程的真实 1440×900 游戏窗口录得：Owner `distribute` 受控四路各 25% / core 100%，跳过首次解锁提示以免引导暂停；`Engine.time_scale=1.0`、无暂停，约 11.046 秒墙钟中游戏时间前进约 10.217 秒。FFmpeg 12Hz、96 编码帧/8 秒，采屏非逐渲染帧与性能基准。四图、视频原帧、驱动、日志、窗口 ID、时间元数据和哈希已独立归档并远端逐 blob 核回读于 `archive/design-docs-before-cleanup-20261031@4d227f40bce88396ebc385880ade4a935ea92658` 的 `modules/public-ui/e845-r12-shared-wip-20261101/`。零态/少路及分配为受控，首次解锁提示导致暂停的无效录制未入归档。**这些仅是本组作者接入证据；原组 R12 尚无独立整页视觉或目标硬件性能通过，本共享组合也未获独立整体审/用户验收。**

同一固定运行源另补 2 路（武器/盾甲）、3 路（再含铁产出）各零载与原生 Owner 分配后带载，共四张当前同壳 1440×900 整屏。2 路 core 100%、两设备各 50%；3 路 core 100%、三设备 34%/33%/33%。作者核全幅，操作行数、标签/滑杆/百分比、均分凹槽与升级承载均可见且未见此四图内明显越界；三路左下设备与管件接触可见。受控静图冻结主流程，**不证明自然 2/3 路解锁、连续工作动态、所有相位或端口逐帧物理连接**。原屏、驱动、状态 JSON、日志与哈希在 `archive/design-docs-before-cleanup-20261031@aeb00c5e3d4464ff789b8b1a76e7cf9dd35356e5` 的 `modules/public-ui/e845-r12-two-three-controlled-20261101/` 已远端逐 blob 核回读；仍只属作者接入观察，待既有整体审按当前图独立判断，四路视频不重复录制。

### 当前线程直接续作：实际指针交接

本执行线程直接接管，原子智能体已完成并退出；不再创建、续派或并行委派。生产运行源仍为 `9838e1e7`，本轮未改已合主线装备、R12内区、公共主题或战斗输入规则。11 的过时“只做闭包准备”已按真实接入事实纠正。

同壳用根窗口鼠标事件完成装备→反应堆→装备→反应堆，并实际点击打开/关闭资源弹层；不是直接发导航信号或程序弹出窗口。19张1440×900原屏与帧号、可见性、处理和子视口状态在 `archive/design-docs-before-cleanup-20261031@60bf5c535dc5a5b2e08e54d7310e7db8c4cb5f29:modules/public-ui/e845-r12-pointer-handoff-20261101/`。导航每段四图为连续绘制帧，整组有间隔，不称完整连续录像。隐藏8处理帧后反应堆可见帧计数不变、处理停止、舞台更新禁用；返回恢复。作者实际打开04/05/06/08/09/12/14/18八张全屏，未见这些已看画面的公共叠层、标题错配或新侵占战场；这不替代原组内区/端口或独立整体品质判断。

当前未发现需凭空追加的公共几何微调；本轮补齐的是既有运行交接证据。R12整页独立判断与反馈后的适配、模块更新后的同版组合仍未完成；全输入状态和目标性能不由本次19图证明。星球旧制作线程已关闭，只保留既有路由对照，不取其新WIP；待接替明确环境及交付固定源后续接。当前不是待用户确认的完整验收稿，不合main。

### 当前独立项与炉池固定源接续

已按既有审核明确缺口完成设置“倍速”下拉的实际点击展开、键盘高亮/确认及Escape退出。运行源仍为 `9838e1e7`：五张完整设置原屏由作者逐张查看，菜单实际为(438,394,330,294)，接在按钮(438,357,330,37)下沿；确认2倍速后原生选值与Owner一致。只补这一条，不泛化为全输入状态或另建复测；未发现需因此修改公共样式的问题。

后续在同分支精确接入反应堆固定 `f7d3d055`，运行提交 **`94fb201916792ca2b3b4677cdb43dbfd6e499fad`**：只取 `r6-smelting.png`、`r6-smelting-work.png`、`modular-module-work.gdshader` 及其 `generate_reactor_devices.py`；与原组同blob，不带无关装备README或旧宿主。导入退出0；同壳四路各25%正常1×运行已取得带载/装备返回整屏及8秒、12Hz、96帧实际窗口视频。作者看两原屏及视频2/6秒全幅，未见此次公共边界退化；炉液/盾场/材质未作最终品质结论，原组继续后两项。

两项证据分别在独立归档 `0c6992de8476aea0df4ff8f09ab412a948b2a3dd` 的 `modules/public-ui/settings-speed-select-handoff-20261101/` 与 `modules/public-ui/f7d3-sluice-shared-20261101/`，运行版本不能混用。前一轮19张指针图仍只对应9838，不冒充新炉池版。星球新执行线程 `01a19581-2564-72c7-9ffd-3cfda70140c7` 正从保全现场恢复制作，本组当前不接其新WIP。当前下一接续为原反应堆盾场/材质的固定更新及明确公共反馈、新星球固定交接；不因“全输入未覆盖”自行新增矩阵或微调。尚无本组合用户确认或main许可。

1. R12 固定源码/运行件已窄接并有当前同壳作者图/短动态；下一步由原组独立整页审及既有整体审按本版真实证据分别判断，若有新修订再精确同步。独审结论不作为制作接入前置，也不由作者图冒通过；当前不重复旧 R5f 图或录像。
2. 星球待原组交完整新主体候选；局部 owned 环/模型修订不足以替整体品质结论。资源 Owner 完整结算闭包按权威契约由相应原组消费，不从旧整树覆盖。
3. 下拉/输入全组合、跨模块最终状态与整页审、目标环境性能仍各按其实际范围交证；旧版静态或工作视频不证明这些项。候选到齐后按 13§6 用**新同版**真实完整画面复核；未授权本组合合 main。

原组当前源入口：反应堆 `implement/reactor-centered-godot` 的 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`；星球 `feat/planet-single-side-ui` 的 `docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md`；装备以已合 main 运行源为准。历史图证与撤回归因只存独立 archive 的模块索引，不作为本入口制作步骤。
