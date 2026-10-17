# 2026-10-17 美术补正原始验收

本分支 `art/playtest-ui-fixes-20261017` 保留独立美术修改；未合并 main。页面原图来自 Godot 4.7.2 的可见窗口，匹配的 native DLL SHA-256 为 `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`。两组脚本均从隔离的用户目录启动，没有改动 `D:\放置`。

## 美术分支原图

- `evidence/factory-idle.png`：奇点装置缩小上移后，底端和接触阴影位于平台环内。
- `evidence/factory-drawer.png`、`factory-active-drawer.png`：覆盖抽屉在闲置及研发时均可读。
- `evidence/animation/frame_00.png` 至 `frame_35.png`：连续 36 张未调色原帧；`factory-research.gif` 仅供快速预览。
- `evidence/equipment-cost-1.png`、`equipment-cost-10.png`、`equipment-cost-max.png`：Lv19 模块的三档报价。脚本触发原按钮的 `pressed` 信号并断言两枚费用控件没有越界。
- `evidence/enemy-native-scale.png`：八类舰体在 40/64px 画布的对照。预览由原始透明 PNG 缩放生成。

## 完整候选的增量复核

从关卡候选 `852a2590` 检出独立临时目录，顺序应用本分支 `59df4250`、`e502a5e5`、`fed7263a`，再应用最终奇点坐标 `(430,92,424,397)` 和阴影坐标。该目录只用于可见 Godot 验证，没有提交或合并关卡分支。

- `evidence/integrated-factory-idle.png`、`integrated-factory-active-00.png` 至 `02.png`：工厂完整候选原图。`capture_integration.gd` 建立已通第 3 关的临时档案以满足真实解锁门槛，再调用 `game.select_tech("singularity")`；进度从 0.43 增至 1.25 游戏秒，探针相位连续前进。
- `evidence/animation/frame_00.png` 至 `35.png`：最终 GIF 的原帧取自完整候选，研究进度由 0.25 增至约 6.95 游戏秒，探针相位经过完整循环。
- `evidence/integrated-equipment-cost-1.png`、`integrated-equipment-cost-10.png`、`integrated-equipment-cost-max.png`：Lv19 临时模块与充足材料档案的完整候选画面。真实报价分别为铁 1600 + 退化物质 10、铁 41500 + 退化物质 10、铁约 952B + 退化物质 210（MAX 可升 102 级）。
- `evidence/godot-integration-gui.log`、`godot-integration-animation.log`、`godot-integration-cost.log` 保留原始运行输出；每次运行退出码 0，只有系统证书库读取提示，没有脚本错误。

费用和解锁档案仅是可复现的画面夹具，不代表从第 1 关实玩到相应等级；关卡流程验收由关卡任务负责。可见截图、按钮回调和动画只验证本任务页面、美术与接线的实际表现。
