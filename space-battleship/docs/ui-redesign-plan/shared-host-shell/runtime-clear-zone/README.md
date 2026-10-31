# 公共壳与 R3：当前制作入口

## 目标与依据

用户认可 R3 共同材质方向，授权公共壳与原生控件推进实机；这不等于各模块排版、全态或整游戏验收。制作前按[13§2.4 可见内容区与整页布局约束](../../../game-design/13-art-interaction.md#24-制作前的布局约束与整页校验)组织；交互和资源事实按[13](../../../game-design/13-art-interaction.md)、[14](../../../game-design/14-ui-contracts.md)与[资源契约](../../../game-design/contracts/resources.md)，版本与审核主体按[07§5](../../../game-design/07-verification.md#5-实施顺序)记录。图标按 ID 读原透明资产，不从整屏截图矩形取图。

## 固定运行源与当前状态

- 本组 `design/clear-zone-host@5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969` 精确装入装备运行源 `81744e5a7da14577ea5792a621529f304ed82b3c`（交接 `7dfa54dc`）及 B01 `519fd7ee82b5c54785bd53b4e36e50f768b6b6de` 的必要模块源、同源 `ResourceAmounts` helper 和 34 项分件资产；公共 `main.gd`、`BridgeTheme`、`PlayerText` 与战斗投影保持本组源。后续 `3c3719bf` 公共状态及 466/6ee 文稿增补已在当前分支，运行组合仍以 5df 的源身份为准，不将文稿提交冒称新模块版本。
- 公共操作材质源是 `BridgeTheme.operation_plate/operation_button/apply_operation_button/apply_operation_select`，取用需 `control-materials.png`、原导入依赖与选择箭头 `stepper-down.svg`；数字角色与 `PlayerText.resource_number` 仍共用现有入口。原生节点应替换旧面层，不加盖板；数量循环只读报价，执行键才提交。顶部“全部升级”旁全局数量键同步各槽模式、报价、可购状态，由装备原组实施。
- 原独立整体审核者已看 `3c3719bf` 十张同版公共设置/资源弹层实图及哈希：已展示状态无所见整页阻断，音乐键真实 hover 相对 normal 有 3894 像素差且 `is_hovered()=true`。审核范围仅该公共静态/按住与受影响悬浮状态；下拉展开列表、输入/SpinBox 全态、模块 plate/select 落位及跨页最终品质未覆盖。此结论不外推后台结算或用户验收。
- 公共原生输入窄修 `86a8ff9eef2704cc10843cfafb5a5b85f71716e5`：`BridgeTheme.apply_operation_select` 直接给现有 `OptionButton.get_popup()` 接 R3 面层、焦点行字色、公共字体和单选标识；`apply_public_input` 把原 SpinBox 步进区平面背景替换为同一材质源，无额外控件。Godot 4.7.2 同版 1440×900 设置页已看伤害/十项倍速展开、行焦点、SpinBox 常态/内嵌输入焦点/不可编辑整屏；图、哈希和驱动保留于 `archive/design-docs-before-cleanup-20261031@86d4536da23c466f5d4006e3929f7d573e4ce600` 的 `modules/public-ui/native-controls-20261031/`。此为本组受影响状态自检，尚未由原整体审确认；键盘确认/全部输入组合态与模块内部落位仍未覆盖。
- 装备 `ce33e869b76c83d698502e23589507e84c738d8e` 于 17:24 获根协调者和原独审有限范围接受并已发用户，随后用户 17:49–54 提出日志化、顶部装饰、舰名牌与刷新性能检查；原组 `36bbbaec201049c5926b6bb1ff9bc9192d58cd85` 正收尾，待其下一固定交接与新反馈，不能沿用 ce33 为新要求已过。反应堆 `3b2c31e2e1b525d7c8ffc1fc4935dc5b2f31f284` 经根协调者检查仍未通过，原组在 `17167e48573202a4b0442352b9983b764e861af3` 记录原版预算动态后继续返修；该记录未改变运行源/审核结论。当前 5df 的旧 `7dfa/519` 仅可复现接入基线，不能作用户认可的组合；旧星球 ac5 仍为品质退回的返回路由对照。

## 当前一步与依赖

本组已将公共原生选择/输入窄修 `b14b3f5f` 的六张同版实图交原独审只读检查，当前仅制作自检，不预报审核结论。装备下一依赖是原组 36bb 后的新固定源及用户新反馈对应记录；反应堆下一依赖是 3b 退修后的固定运行候选；星球仍待新主体固定源。候选到位后精确同步源码与必需素材，保留公共资源身份、顶部退出、输入焦点、x808 导航和战斗有效空间，再以同版整屏判断公共接缝与共同材质。当前 5df 的四张同进程图只证明旧接入事实，不代替新候选证据；不重复原组全链或性能复测。各组入口在其各自制作分支：装备 `art/equipment-materials-main-20261029` 的 `docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md`；B01 `implement/reactor-centered-godot` 的 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`；星球原组的 `docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md`。

后台 f924 的资源整数方法仅在本组合中按需窄接 B01 报价/helper；公共余额兼容旧/新 Owner 行且不在 UI `ceil`。完整七文件 Owner 结算闭包、星球新主体、反应堆目标环境性能、装备新排版/全局倍率与最终跨页审核仍由各责任方给固定源或结论，不从旧分支整树覆盖。未授权合 main。
