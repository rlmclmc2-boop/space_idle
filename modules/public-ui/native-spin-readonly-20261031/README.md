# 公共 SpinBox 只读态窄修图证（2026-10-31）

运行源：`design/clear-zone-host@3991713d6a0a4a406b950b2cbd4b1ad142caf34e`；Godot 4.7.2 / 1440×900 / 主入口设置页。原生控件通过 `BridgeTheme.apply_public_spin_editable` 在真实 `SpinBox.editable` 状态间切换。

- `normal.png`、`focus-editable.png`：60 秒可编辑常态/内嵌 LineEdit 聚焦。
- `readonly-focused.png`、`readonly-blurred.png`：不可编辑时仍可聚焦复制，但箭头和焦点边弱化；原生 LineEdit 自动变只读。
- `reenabled-focus.png`：重新可编辑后箭头/焦点恢复。
- `driver.gd.txt`：主场景驱动；受控点击不可编辑箭头时值 60→60，日志无脚本错误。

仅本组受影响可见状态与一次拒绝点击自检，待原整体审；未覆盖步进按住、键盘输入全组合、各模块内部或自然流程。旧 `native-controls-20261031` 中 PopupMenu 是直接 `popup()` 指定位置/程序设焦，只证明绘制，不证明 OptionButton 真实点击定位/键盘确认。
