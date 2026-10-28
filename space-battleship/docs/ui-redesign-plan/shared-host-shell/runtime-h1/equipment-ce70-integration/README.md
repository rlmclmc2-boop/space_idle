# 装备ce70光学修订 × 当前共享宿主

运行代码`design/shared-host-shell@c84c703fafe2ce8523480cf62908979bc876ae80`，宿主基线21d0aaab。原组源码`ce70b594b6ffc111eb888d11562312526ebfc675`、[原组f76d328f交接/视觉证据](https://github.com/rlmclmc2-boop/space_idle/blob/f76d328f88019f18c54737ae8c85bbf2bd2f67c3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/README.md)。原Astra仍审装备视觉；本组合仅完成共享接入，未合main。

## 保留范围

只替换equipment_panel为ce70内部实现，再迁回已关闭的公共顶部下背景退出差异：_draw的旧标题底板条件退出/原机库顶部薄片，set_shared_host的标志与重绘。相对ce70仅这两方法和对应两本地缓存字段有差异；其余方法全部逐字节相同，包括工作台排版/字形、按需回执、短反馈、三秒计时、候选、命令、批量、冷却和投影。没有拿宿主旧工作台覆盖最新内部方案。

ce70引用的既有正式图/字体/机库素材在当前基线相同，无新运行素材依赖。原main、shared_host、Reactor R4、星球、GameSession、Equipment/Economy所有者均相对21d不变；现有P2/裁取修复与公共壳保持。[准确源身份/环境/哈希](evidence/environment.json)。

## 回执Popup与区域

原组PopupPanel由装备自持，has_exclusive_ui、exclusive_ui_changed、prepare_host_hide(force)均保留ce70。普通离页/收起在Popup打开时拒绝；force关闭Popup和批量并收短反馈，保留原始回执字符串。宿主会话释放路径先调用此端口再隐藏视图/窗口，未把只读回执当领域状态或新存档字段。

本次1440×900实测Popup位置(104,230)、大小600×420，完整位于(0,65)/808×835模块内容区；不压公共栏、不越入战场。Popup打开后原组独占通知可读，公共入口禁用，Space/G不改全局暂停/驻守，战场点击不投递。关闭后的UI焦点仍沿已审“战场首击撤焦、后续操作恢复”路径，不绕过共同门禁。

## 同版整屏与14项必要操作

[普通组合](evidence/normal-current-host.png) · [一次真实成交短反馈](evidence/purchase-feedback-current-host.png) · [原始回执Popup](evidence/receipt-popup-current-host.png) · [关闭后组合](evidence/closed-current-host.png)。前三图均已实际view_image；属于当前公共顶部下正式main/Session/native画面，不是原组旧main或拼贴。

[14项记录](evidence/observations.json)全部通过：唯一装备路由/808×900画布/背景退出、原战场投影、一笔原Owner真实回执、Popup区域/原文/独占、导航/收起/Space/G/战场鼠标阻断、强制隐藏后转路由、本地关闭按钮、战场撤焦和快捷键恢复、宿主释放强制关闭、独占信号。宿主释放检查调用真实_prepare_host_release，未执行导入/重铸替换事务。

为打开真实回执，原任务隔离/tmp存档中实际鼠标购买+1一次，Owner回执accepted、实际花费65铁，未注资。临时存档继承此前已注明的开放/星球状态夹具，不作自然发展或完整交易验收；没有重跑三笔频繁购买、多资源/长MAX、防御、全舰、冷却或四保护矩阵。记录只有此次原始回执，不向UI塞合成成交信息。

[实际日志](evidence/godot-live.txt)无脚本/资源错误，仅既有Xorg VSync警告；[4.7.2解析检查](evidence/godot-check.txt)及Git diff检查通过。该原尺寸证据不扩大为全窗口/DPI、模块视觉、全自然流程或V0通过。原装备Astra继续审视觉，本组不另开复测/审核。

当前无权限/运行阻塞，交原布局Astra核本次组合边界，不合main。
