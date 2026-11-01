# B01 R12：正式配置的自然开放路径

项目工作树为 `implement/reactor-centered-godot@4278ef9334cf313c0a1ab4ae4ab321fc6b464f96`，运行反应堆资产固定于 `0bc17ae48107972c88a84069cf5221bf5c1cbb0f`。本地 Godot 4.7.2 与既有 native 模块运行正式 `generated/config.json`；没有修改生产配置、写入 grant、恢复伪造进度或调用解锁注入。正式 unlock 表只有 `feature/reactor` 在关卡 1 清关开放、`reactor_module/condensation` 在关卡 15 清关开放；前三路随 feature 开放。

`natural-stage1.gd`、`stage1.log`、`stage1.png` 是一次全新临时用户目录的正常开局。驱动通过公开 `session.frame(1/60,false)` 连续调用按 1× 固定步推进，并用公开 `dismiss_guidance` 关闭实际出现的教程提示；这是**压缩墙钟的自动推进**，不是人工等待或目标硬件性能证据。原始日志显示初始 `cleared_stages={}`、feature=false、enabled=[]；2796 次调用后关卡 1 真正清关，Owner 返回 feature=true、凝聚=false、enabled=[weapons,defence,smelting]。原尺寸整屏显示三路设备/管路/控制行，凝聚整套隐藏。

`natural-stage15.gd` 与 `stage15.log` 为从新游戏继续沿同一公开帧入口尝试第 15 关：真实推进至关卡 2，但在第 2 关战斗达到脚本的无新关卡上限，凝聚仍关闭。`continue-stage15.gd` 与日志从这一临时正常存档继续，使用装备页同一 Owner `buy_all_levels(1)` 合法购级；期间有教程提示与一次死亡撤退，随后到关卡 2 末点 0.88 战斗。连续 30000 次调用未清关，不推断为引擎锁死。`inspect-purchase.gd` 与日志记录该临时存档的激光已购 6 级、装甲已购 5 级、余量铁 28／铀 145，再购返回 `NoChange`。

本包完成了关卡 1 → 三路自然开放的同版验证；关卡 15 → 凝聚自然开放**仍未验证**，需要实际玩法策略与资源/装备推进到关卡 15，不得由受控四路画面外推。`SHA256SUMS` 覆盖本目录除自身外的每个文件。归档只在 Git archive，不进入制作树、主线或 Library。
