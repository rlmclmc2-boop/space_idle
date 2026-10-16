# 粗磁轨与敌方伤害数字叠层修复

图14 的数字只剩“2.”：`main.gd:draw_foreground_overlay` 在 `battle_layer` 绘制敌方伤害浮字；`battlefield.gd:_draw_muzzle_cues` 随后在 `battle_clip` 中较晚添加的 `pulse_layer` 绘制粗磁轨。二者都为 `z_index=0`，但同层绘制顺序使轨迹盖过浮字。`battle_hud_layer` 是另一节点，只调它的 z 值不会移动这段实际浮字绘制。

现保留原浮字布局、数值和衰减，只把绘制调用放在 `battle_clip` 中 `pulse_layer` 后面的 `BattleDamageText` 节点；上层 HUD 与教程仍在其后。战斗、武器轨迹宽度、伤害数字内容、敌舰几何均未改变。

`15-rail-damage-layer.png` 是隔离用户目录、关闭存档的正式 `main.tscn` 定点画面：用真实磁轨反馈绘制函数画 56 像素宽的竖轨，横向的“2.76K”浮字位于正交交点；完整文字和底板可见。`rail-damage-capture.log` 记录 `pulse_index=4`、`damage_index=5`，截图保存成功。这是显示顺序的定点验证，**不是**父审真实 3-7 同帧画面；仍请父审在同一云端 UI 复看该场景。敌舰炮台／舰体穿模指向仍不明确，未在此改动。
