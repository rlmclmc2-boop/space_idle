# 选中定位徽标避让窄修正

固定源码 **5b4f72331038622ce739578fcdf3823a0a0b4716**，原目录/实现分支，未合main。根审/独审已确认b935原两项关联阻断改善可关闭，本批不重开布局，仅修徽标被终端遮挡：原支承、定位线、目标框、控件、开放态、main/业务/config均不改。

优先看 [武5完整徽标](evidence/selected-weapon-4.png) 与 [武3移到空位](evidence/selected-weapon-2.png)；其余同版逐槽图：[武1](evidence/selected-weapon-0.png)、[武2](evidence/selected-weapon-1.png)、[武4](evidence/selected-weapon-3.png)、[防1](evidence/selected-defence-0.png)、[防2](evidence/selected-defence-1.png)、[防3](evidence/selected-defence-2.png)。8张均真实Godot 4.7.2根视口1440×900原像素，未裁切、缩放、拼接。

只改选中徽标的整块32×22矩形选址，不改节点z层。目标周围有限候选依次避开全部终端矩形外扩4px、其他部件可见矩形外扩2px，并留在机库区域内；文字和底板共用同一矩形。防3仍优先保留已通过的邻近位置。若未来未验证布局没有空位，则不画被裁碎的徽标；本次8槽都找到完整位置，无隐藏回退。无新领域读取、逐帧alpha扫描或样式重建。

实际武5矩形 **(484.3088,475.007,32,22)**，右缘516.3088，与防御2卡x522有5.6912px空隙；武3矩形 **(419.1739,318.9242,32,22)**，不再进入x536起的武5卡。原始 [badge-operations.json](evidence/badge-operations.json)逐项保留最终矩形、终端矩形、部件框、文本及所有者比较。真实鼠标事件逐槽点击，native主场景/Session/Equipment均实际运行，`BADGE_CAPTURE_COMPLETE failures=0 rows=8`；8个徽标均完整、无槽卡相交且文字宽度可容纳。

受控准备只开放正式Heavy并经原equip_slot/native装入对应武器/防御；等级沿新建默认等级、钱包为新局0，只验证本次徽标，不拿此图冒充原高等级交易场景。新局设置/存档为全新独立/tmp路径，启动确认无recovery。原b935/8d897144中的交易、开放状态、四项保护和静态遮挡边界仍保留原证据；按本轮窄范围没有重跑无关交易/原四项，也不扩大其结论。防御仍为UI代理而非原生武器挂点，选中实体/代理定位规则未变。

[manifest.json](manifest.json)绑定固定源码和所有证据SHA256；驱动与原日志保留。本轮只交徽标避让给原审，不自判整体视觉或全V0/V2通过；未扩其他舰型/长值组合、Windows/DPI、长期性能。无环境/审批阻塞，旧证据与缓存完整保留，执行者未实际上下文压缩，固定交付后不自行启动新批。
