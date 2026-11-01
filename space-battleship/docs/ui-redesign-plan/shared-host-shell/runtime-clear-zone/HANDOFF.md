# 公共壳制作交接

设计目标与完成标准见[13](../../../game-design/13-art-interaction.md)；本页仅记录现场、覆盖和下一步。本执行线程直接制作，不使用子智能体。

## 当前固定现场

- 制作分支 `design/clear-zone-host`；运行源 `94fb201916792ca2b3b4677cdb43dbfd6e499fad`，交接记录更新至 `95f393144394481512bce79a5d059da63c408d5d`。工作区 `/workspace/space_idle` 继续复用。
- 基础 R12 为 `0bc17ae48107972c88a84069cf5221bf5c1cbb0f` 的30件运行闭包；另从 `f7d3d055` 精确消费 `r6-smelting.png`、`r6-smelting-work.png`、`modular-module-work.gdshader` 和 `generate_reactor_devices.py` 四件。公共 `main.gd`、ZoneShell、BridgeTheme、资源身份/格式及导航按住状态保留，不以模块旧宿主覆盖。
- 装备保留已合 main 的 `e845ca58afd39184c3d4c5743021480e393adf74`；星球仅为既有路由返回对照，不是品质通过。新星球线程 `01a19581-2564-72c7-9ffd-3cfda70140c7` 从保全现场恢复制作，本组不取其新 WIP。
- 当前挂载几何为1440×900：模块x0..808、顶轨下y65；导航x808..855.875；战斗有效投影x855.875..1392.125、scale0.9375。反应堆 `_init(owner,inputs,payment,publish,can_pay)`、`bind_presentation`、`bind_purchase_quote` 和808×835舞台不变，端口由PortContract读取。

## 实际覆盖与证据

以下均为作者接入观察，未获本组合独立整页或用户验收；受控开放、分配不等于自然解锁。

- 旧运行源 `9838e1e7`：1/2/3/4路受控整屏、四路正常1×短片；独立归档 `4d227f40bce88396ebc385880ade4a935ea92658:modules/public-ui/e845-r12-shared-wip-20261101/` 与 `aeb00c5e3d4464ff789b8b1a76e7cf9dd35356e5:modules/public-ui/e845-r12-two-three-controlled-20261101/`。
- 同一9838源的实际根窗口指针双向导航与资源弹层开关：19图，作者打开其中8张完整画面；隐藏8处理帧后反应堆可见帧计数不变、处理/舞台更新停止，返回恢复。各导航四图连续，整组有间隔。归档 `60bf5c535dc5a5b2e08e54d7310e7db8c4cb5f29:modules/public-ui/e845-r12-pointer-handoff-20261101/`。
- 设置倍速下拉的既有真实展开交接缺口已补：仍是9838源，5张完整设置页均实际查看；点击展开的菜单对齐按钮下沿，键盘确认2倍速后原生选值与Owner一致，Escape退出不改值。只覆盖这一条，不泛化全输入。归档 `0c6992de8476aea0df4ff8f09ab412a948b2a3dd:modules/public-ui/settings-speed-select-handoff-20261101/`。
- **当前94fb源**：Godot4.7.2导入退出0；同壳四路各25%带载与装备返回原屏、正常1×8秒窗口录像（12Hz、96编码帧）。作者看两原屏及视频2/6秒完整帧，未见此次新增公共边界退化。墙钟约11.077秒、游戏时间前进约10.383秒；采屏不是逐渲染帧或目标性能结论。归档 `0c6992de8476aea0df4ff8f09ab412a948b2a3dd:modules/public-ui/f7d3-sluice-shared-20261101/`。

归档均在 `archive/design-docs-before-cleanup-20261031`；不得将9838证据标作94fb本版。当前炉液过程、盾场/材质、少路数动态、目标性能不由本次时间样本判为通过。

## 下一步与准确依赖

1. 当前同壳材料可交父级按完整页面判断；按明确公共反馈继续适配，不以原组独审作为可撤回接入的前置。
2. 反应堆原组继续盾场/材质，取得固定修订后精确同步并保留公共源；本组不代画内部设备。
3. 星球等待新线程固定交接，不接关闭旧线程的新WIP。装备已完成版本继续保留。
4. 当前未报需另行修改的独立公共缺陷；不将“全输入状态”等泛项扩大为新矩阵、独立复测或无需求微调。本组合未授权合main。

本次按 `docs/spec-scope-host-20261101@cd0906537c61202e76e54653e7e0a67acf04de3f` 的40条文档清单消费规范拆分，保留本组并发运行修改与上述实际记录。制作入口只导航规范，状态集中本页；文档消费不另跑游戏。
