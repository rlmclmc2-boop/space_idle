# 公共壳与 R3：当前制作入口

## 目标与批准依据

用户认可42ea4ffc格式修后14:52实际送达的R3共同风格方向。当前目标是让公共壳、原生控件及各模块形成完整桌面宽屏；方向认可不等于实机/全状态验收。有效规范只见[13](../../../game-design/13-art-interaction.md)，连接只见[14](../../../game-design/14-ui-contracts.md)。图标必须按ID用原透明纹理，不从旧整屏裁图。

## 固定源与现场

- `design/clear-zone-host@5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969`；由main e3b38d7b发展，各组最新版本不在同一运行树。
- 059ac56b公共材质接口`BridgeTheme.operation_plate/operation_button/apply_operation_button/apply_operation_select`已存在；取用时包括control-materials.png/导入依赖及stepper-down.svg。
- 3c3719bf在真实设置节点补接OptionButton/输入框，区分pressed与hover_pressed；旧“接口存在即设置已装”及旧hover同像素记录不能作为当前通过依据。
- 装备7dfa54dc和反应堆519fd7ee已各自消费6e0公共材质，旧“二组未消费”作废；5df3d3dd已精确合入装备81744面板及B01 519f四脚本/报价/helper/34项运行资产，未覆盖公共main/theme/formatter。原组WIP未读取或清理。

## 当前一步、完成标准与下一步

原独立整体审核者对3c3719bf十张公共设置/资源弹层图已作有限视觉检查，所见状态无整页阻断（本次源记录未注明模型），不覆盖展开列表/输入全态或模块内部。**当前5df3d3dd公共壳＋装备＋新B01组合待既有独立整体审核者审核**；作者有同进程四张完整切页/均分/MAX图，星球仅旧退回基线路由对照。本Astra只核供应方源码blob一致及来源，未做视觉/性能复测；未核见此组合附件已送用户，不写待用户确认。

整体验收须同一组合完整页与实际操作，涵盖面板、字体、费用行、透明图标、选择/执行/禁用/焦点及跨页一致性。候选固定后继续各组尚未覆盖状态，不恢复强制三分支立即接公共壳或等待Figma；右侧预留仍由战场组负责。

## 当前依赖

[装备](../../../verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md)、[B01](../../../verification/reactor-centered-godot/evidence/b01-redesign/README.md)、[星球](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)各自记录真实未完项。公共显示兼容Owner新旧整数行并已窄接B01报价/helper，仍未合完整f924结算闭包，也未消费c38f1c2b保存去绑定；由原组按必要方法整合，不UI ceil或用旧后台树覆盖新UI。四组均未整体通过或合main。
