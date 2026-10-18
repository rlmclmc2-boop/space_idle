# 界面刷新、音乐与文案

| 修改范围 / 目的 | 按需入口 |
|---|---|
| UI 刷新、导航与弹层 | `test_performance_ui.gd` 检查船员局部更新、隐藏恢复、焦点/草稿/滚动、装备控件复用与 HUD 绘制依赖；`test_workspace_shell.gd`、`test_overlay_layout.gd`；按实际变化选页面专项。旧 `test_local_ui.gd` 依赖已删除的科研管理按钮，暂不作为验收入口。 |
| 音乐与开关偏好 | `test_bgm.gd` |
| 文案 | `test_ui_text.py`；涉及运行时文字行为时用 `test_ui_text.gd` |
