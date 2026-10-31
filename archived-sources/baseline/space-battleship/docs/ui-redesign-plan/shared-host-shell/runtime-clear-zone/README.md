# 公共壳与 R3 共同材质：当前制作入口

## 目标与唯一批准依据

用户已认可`42ea4ffcb7a2fb0f8fc2f64d04a23b0db1306cde`格式修后的R3共同方向，14:52实际发送的[并排](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/coherent-controls-r3/compare-2400x1030.png)、[晚装备](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/coherent-controls-r3/equipment-late-1440x900.png)、[B01](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/coherent-controls-r3/reactor-1440x900.png)是批准依据。它们是静态代表页，非实机/全状态/最终统一通过；旧“待用户意见”已经结束。

## 固定源与现场

| 项目 | 本次可核快照 |
|---|---|
| 分支/固定源 | `design/clear-zone-host@6e0e86c80d7cc7ee4f8623fca929c2f4828b6215` |
| 代码基线 | 从`main@e3b38d7b6d8256f6031e1b086c7db7812b6a441f`发展；不继承旧概念分支整棵运行树 |
| 公共显示 | 数字角色190a；资源格式36258；e1b580接受Owner整数行；059ac56b已固定R3公共运行材质包；未接完整f924整数Owner闭包 |
| 当前组合限制 | 历次公共壳/装备/旧B01/星球的限定图仅覆盖各自固定组合，不包含新B01模块化舞台或当前星球WIP |

## 当前一步、交付标准与下一步

**当前一步：**原装备/B01消费已固定的R3最小公共材质包。运行源`059ac56b`、文档源`6e0e86c8`提供`BridgeTheme.operation_plate/operation_button/apply_operation_button/apply_operation_select`；图集`control-materials.png`及其导入依赖、选择箭头`stepper-down.svg`一并取用，数字角色沿已有接口。公共源码先替换原样式，两组内部尚待消费。

交付标准：原组按plate/card九宫格、内距、secondary/commit角色及normal、hover、pressed、hover_pressed、selected、disabled、focus适配原节点，再以同版完整整屏和真实操作判断。公共设置/弹层有限状态已固定，不能代替两组内部与全局跨页通过；接入后继续各自未完项。

## 依赖、明确退点与证据覆盖

- 图标必须按稳定装备/资源ID用原透明纹理，禁止从旧整屏截图裁图标。[装备精确诊断](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/r3-native-adaptation/README.md)已找到R3静态矩形底来源；早期“原PNG内部不透明像素”记录不能作为本次直接根因或批量抠图依据。标准只维护于[13§2.2](../../../game-design/13-art-interaction.md#22-全局信息层级与适配)。
- `f9244a30`已修a83奖励校验/chrono退点并获限定只读复核；旧a83等待修复状态作废。公共显示目前仅兼容旧/new整数行与`数字×10^指数`文本，尚未整合七文件结算闭包；[资源契约](../../../game-design/contracts/resources.md)为唯一后台边界。
- 装备R3/排版/残字/裁剪由[装备入口](../../../verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md)登记；新独立核心/管路与性能由[反应堆入口](../../../verification/reactor-centered-godot/evidence/b01-redesign/README.md)登记；整体环带/四设施由[星球入口](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)登记。都未整体完成，不拿旧组合替其新源验收。
- 资源整数及k/m/b/t/kt/e、普通资源无.0/大数一位小数、数字角色、费用两键、逐资源不足只引用[13](../../../game-design/13-art-interaction.md)与[14](../../../game-design/14-ui-contracts.md)，不再在过程日志复写规则。
- 用户已撤回立即强制三制作分支接公共壳；不恢复该要求。公共控件共源在项目内维护，不继续等待Figma。右侧预留区仍由战场组负责，不添加环境/特效。

公共源和有限状态证据见[6e0原记录](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md#r3-同源操作材质的可运行公共入口原组内部待消费)。14:52原三图字节保留；[透明图标修订源](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/coherent-controls-r3-transparent-icons/render-study.gd.txt)另存，仍是静态稿，不冒称原发送附件或运行图。

## 稳定历史索引

[完整历史](HISTORY.md)保留原579行、全部组合版本及证据。按问题读取：[R3批准/格式](HISTORY.md#r3-静态示例资源文字与公共格式对齐)、[数字角色](HISTORY.md#装备最新文字列b01-同族材质-r3静态方向已送用户评价)、[旧整数接口适配](HISTORY.md#后台整数候选-a83ad9c8公共行适配与-owner-依赖)。旧R1退回、R2候选、旧“当前52c/packed/待原组”仅是历史；不读“末几节”。
