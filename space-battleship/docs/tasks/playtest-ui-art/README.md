# 2026-10-17 首代科技树美术与试玩 UI 验收

工作分支：`art/playtest-ui-fixes-20261017`，起点 `main@3a0f4028`。本目录保留 Godot 实际渲染的原始证据；测试使用独立工作区、Godot 4.7.2，以及四份 native 源文件逐份匹配的 DLL `DCCD40B52E086444EDD7291D2BEAD736B96F7876A53F989DF5549A1D4F99B30A`。未写入 `D:\放置`。

## 直接查看

- `evidence/factory-idle.png`：工厂空闲，机器落于平台，机器人不加工。
- `evidence/factory-drawer.png` 与 `evidence/factory-active-drawer.png`：覆盖抽屉及研发中覆盖状态。
- `evidence/factory-active-00.png` 至 `05.png`：真实 `game.select_tech("singularity")` 后连续阶段截图，进度与探头位置同步变化。
- `evidence/factory-paused.png`：游戏暂停后，机器人相位不再前进。
- `evidence/factory-research.gif`：36 帧、3.6 秒预览；`evidence/animation/frame_00.png` 至 `35.png` 为未经 GIF 降色的原始连续截图。
- `evidence/enemy-intel-point3.png`：第 1 关第 3 波，ID `271005×2`、`271006×1`、`271007×1`，两个同名 ID 分为 01/02。
- `evidence/enemy-slot-inventory.csv`：前 7 关共 53 个战点的原始 `group.slots` 刷怪权威数据。
- `evidence/equipment-fee.png`：装备卡使用资源图标和数值；资源名称保留在悬停提示。
- `evidence/enemy-native-scale.png`：八种舰体按 40px/64px 战场宽度并排核对；`evidence/factory-contact-preview.png`：八台装置接触点静态预览。

`godot-import.log`、`godot-main-smoke.log`、`godot-capture.log`、`godot-animation.log` 保留引擎原始输出。导入与场景运行退出码均为 0；仅有此环境的系统根证书读取报错，没有脚本错误。动画日志中真实进度从 0.25 增至 6.87 游戏秒；暂停与抽屉展开前后的探头相位逐值相等。GIF 经检查为 36 帧，首帧与第 18 帧有 248 个抽样像素不同。

## 范围与交接

美术改动在 `ai_tech_factory_art.gd`、`ai_tech_factory_page.gd` 的标题几何、`ai_tech_view_model.gd` 的只读暂停投影、`enemy_intel_page.gd`、`enemy_visual_identity.gd`、`equipment_card.gd`、`equipment_tab.gd`，及相关静态资产。`main.gd`、游戏数值、刷怪表、功能门槛均未修改。

换装倒计时消费功能方的 `game.equipment_switch_remaining(category,index)` 和 `slot_equipment_locked()`；页面自身只对显示轮询节流，不持有倒计时。截图使用的起点 main 尚无该游戏接口，故冷却显示需在功能分支合并后联测。功能分支 `feat/unlock-notice-copy-20261017@a6bb9325` 已提供接口。

远端推送未完成：自动审批认为用户尚未明确授权此任务分支向 GitHub 外部远端推送。此交付为本地提交，供父线程读取与审查。GUI 窗口已释放给功能方。运行缓存、导入元数据及临时复制的 native 二进制已清理，原始证据保留。
