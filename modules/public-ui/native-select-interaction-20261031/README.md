# 公共下拉真实点击与键盘确认（2026-10-31）

运行组合：`design/clear-zone-host@bc57c5261178a7240e806a7fcf98f7e998e464e8`；Godot 4.7.2 / 1440×900 / 主入口设置页。此包是受影响原生控件实图和驱动，不是独立测试工程或全态验收。

- `before-click.png`：伤害数字当前“全部”。
- `clicked-open.png`：向真实 OptionButton 中心发送按下/释放，原 PopupMenu 在 (438,610) 展开，紧接控件 (438,573,290×37)。
- `keyboard-down.png`：菜单窗口获焦后送两次 Down，第 1 项“仅暴击”获焦。
- `keyboard-confirmed.png`：Enter 关闭列表，OptionButton `selected=1`、正文“仅暴击”，主场景 `_damage_mode=critical`。
- `driver.gd.txt`：同场景操作驱动，未直接调用 `PopupMenu.popup` / `set_focused_item`。

只证明这一设置下拉的真实鼠标/键盘链、定位和可见状态；未覆盖倍速长列表点击确认、触屏、全部输入状态、模块内区或跨页验收。
