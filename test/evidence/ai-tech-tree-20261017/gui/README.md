# AI 科技树真实主场景验收

Godot 4.7.2 GUI，OpenGL Compatibility。`test/test_ai_tech_tree_gui.gd` 加载实际 `main.tscn`、`BattleGame` 和科技页。运行使用 `test/work/` 下的隔离工程与用户存档；未读取或修改玩家存档。

原始日志：`../rules-34-pass.log`、`../gui-integration.log`。GUI 结果为 23 项通过、0 项失败。

- `00-choose-research.png`：真实游戏初始状态与选研抽屉。
- `01-research-progress.png`：选择武器精度后进度与预计时间。
- `02-uranium-shortage.png`：铁投入扣款，铀余额不足时仅暂停铀加速。
- `03-investment-recovered.png`：铀余额恢复，两种投入均扣款与加速。
- `04-tab-return.png`：切到装备页再返回，进度保留。
- `05-save-reload.png`：手动保存后重新加载主场景，选研、投入与进度恢复。
