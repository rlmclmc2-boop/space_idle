# 公共壳与 R3：当前制作入口

## 当前目标

用户已认可 R3 的共同材质方向，授权公共区域与原生控件在游戏内推进；各模块内部、完整操作、性能及整组品质须按当前版本另审。制作以[13§2.4 可见内容区与整页布局约束](../../../game-design/13-art-interaction.md#24-制作前的布局约束与整页校验)为准；字体/资源/数量与费用语义依[13](../../../game-design/13-art-interaction.md)、[14](../../../game-design/14-ui-contracts.md)及[资源契约](../../../game-design/contracts/resources.md)。原生图标按身份读取透明资产，不从整屏截图截取矩形图块。

## 固定运行基线与公共契约

- 当前可撤回共享组合运行源码 `design/clear-zone-host@9838e1e77a60f31070bc472e9ed7ca6eca4161ef` 已精确接 R12 `0bc17ae48107972c88a84069cf5221bf5c1cbb0f` 的 30 个运行件。旧 `3504a52d` 视觉判断被用户否决，只保留于独立归档，不再预载其旧反应堆绘制路径、复用旧图或作为本版验收依据；已退役资产暂留仓库，避免误删其他引用。
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

1. R12 固定源码/运行件已窄接并有当前同壳作者图/短动态；下一步由原组独立整页审及既有整体审按本版真实证据分别判断，若有新修订再精确同步。独审结论不作为制作接入前置，也不由作者图冒通过；当前不重复旧 R5f 图或录像。
2. 星球待原组交完整新主体候选；局部 owned 环/模型修订不足以替整体品质结论。资源 Owner 完整结算闭包按权威契约由相应原组消费，不从旧整树覆盖。
3. 下拉/输入全组合、跨模块最终状态与整页审、目标环境性能仍各按其实际范围交证；旧版静态或工作视频不证明这些项。候选到齐后按 13§6 用**新同版**真实完整画面复核；未授权本组合合 main。

原组当前源入口：反应堆 `implement/reactor-centered-godot` 的 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`；星球 `feat/planet-single-side-ui` 的 `docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md`；装备以已合 main 运行源为准。历史图证与撤回归因只存独立 archive 的模块索引，不作为本入口制作步骤。
