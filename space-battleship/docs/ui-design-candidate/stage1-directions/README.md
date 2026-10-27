# 阶段1：统一设计思路模板与四方向参考

**新方向探索，全部未选定、未通过视觉/整屏审核，不接游戏。** 旧稿整体未通过的状态不变。依据规划0379d322，已按正式入口main96b1e82a同步后的作用域继续；仅桌面参考，不改正式规范/后端/Excel，不合main，不生成最终资产。

## 先统一模板，再比较方向

[统一模板v1](template.md)先列目标、主场景、注意力与信息层级、空间、连续路径、视觉语言、事实与取舍。14契约是原契约线程提供的事实输入；模板已收到[原契约只读核对](https://github.com/rlmclmc2-boop/space_idle/blob/76dbe1e2e0f12341aa4d630cceea6ab8314fdef1/stage1-contract-review.md)，领域边界基本可用；仍不冒称接口齐备或双方整体审批。阶段1不预定左右分屏、同尺寸模块面板、精确金额输入或比例粒度。

[打开比较页 index.html](index.html) · [打开交互参考 preview.html](preview.html) · [组织关系SVG](overview.svg)

从`space-battleship/`运行`python -m http.server 8765`，浏览`http://127.0.0.1:8765/docs/ui-design-candidate/stage1-directions/index.html`。无需构建或联网依赖。审阅工具可切四方向和固定状态，不属于游戏UI；截图使用`capture=1`隐藏该工具，产品区域尺寸保持不变。

| 方向 | 实质差异 | 可交互入口 |
|---|---|---|
| A 全景＋侧浮坞 | 默认环境/交火，工作点按需浮出，模块开合改变战场屏幕位置；场景型浮坞可扩大 | [A](preview.html?direction=a) |
| B 下沿工作台 | 空间上下分工；底部横向持续整备，打开后压缩上方观看域 | [B](preview.html?direction=b) |
| C 舱室模式＋战况仪 | 工作时由舱室成为主场景，战斗只保留状态；一步切回完整观看 | [C](preview.html?direction=c) |
| D 常驻双焦工作场 | 工作场/舰桥概览和交火长期并置，可调分界；默认开合仍使战场中心横移约101px | [D](preview.html?direction=d) |

四稿刻意共用字体、资源、色彩和同一组样例行为，差异在观看/操作生命周期及空间归属，非换色变体。当前场景与SVG是粗意图，不将机舱符号、舰体大图或可点击控件当成最终场景品质。

## 同任务、同状态整屏

| 方向 | T1空闲 | T2反应炉打开 | T2舰装打开 | T3连续操作后 | T4不足/深入 |
|---|---|---|---|---|---|
| A | [图](evidence/a-idle-1440x960.png) | [图](evidence/a-reactor-1440x960.png) | [图](evidence/a-fleet-1440x960.png) | [图](evidence/a-continuous-1440x960.png) | [图](evidence/a-failure-detail-1440x960.png) |
| B | [图](evidence/b-idle-1440x960.png) | [图](evidence/b-reactor-1440x960.png) | [图](evidence/b-fleet-1440x960.png) | [图](evidence/b-continuous-1440x960.png) | [图](evidence/b-failure-detail-1440x960.png) |
| C | [图](evidence/c-idle-1440x960.png) | [图](evidence/c-reactor-1440x960.png) | [图](evidence/c-fleet-1440x960.png) | [图](evidence/c-continuous-1440x960.png) | [图](evidence/c-failure-detail-1440x960.png) |
| D | [图](evidence/d-idle-1440x960.png) | [图](evidence/d-reactor-1440x960.png) | [图](evidence/d-fleet-1440x960.png) | [图](evidence/d-continuous-1440x960.png) | [图](evidence/d-failure-detail-1440x960.png) |

T3实际回放：W1购级两次→选W2→直接选导弹→确认换装→选W3购级→回W1。四稿均8个直接动作；工作台没有撤下，W1当前21级、下一笔22级报价3.5K可见；W2保18级且换装锁仅绑定本槽。T4失败时仍能切其他槽。这里的固定回执不是实际支付/接纳验证。

[逐方向模板与取舍](comparison.md)列观看损失及几何粗记录，不按单个数字选“最佳”；[版本与接口边界](boundaries.md)区分主线、候选及待核对。科研/星球只作可变场景容量粗参照，其他模块只列共同框架兼容性假设，没有提前全面精做。

## 证据身份与下一门槛

20张1440×960整屏来自同一组HTML/CSS/JS；[task-replay.json](evidence/task-replay.json)包含源码哈希、实际动作、控件中心点路径和显示矩形。制作自检仅排查缺图、JS异常、溢出、路径中断与隐式暂停，没有新增独立复测、没有运行游戏。

原型没有完整战斗装配/接触/掉落、真实费用求值或经济账本，也没有资产生产与安装。不能关闭G9、认定native修复回归、宣称V0通过或给新倍率/规则授权。C模式与旧“并列”文字的差异显式记录，未擅改规范。

下一步仍是模板剩余共同讨论、四方向的父审/用户审图取舍；未过阶段1门槛，不进入阶段2反应炉完整样板。没有执行权限阻塞；原契约只读核对已回传；所列最小接口缺口继续待补，不据报告授权新增业务实现。

## 本轮小修与离线包

A的不足反馈已贴近购级操作；D的“位置保留”结论撤回并按实测横移100.8px记录。反应炉常态先看意图/占比与效果样例，完整供能金额按需展开；占比不构成分配粒度或新映射，效果例未由详情金额求值。深入详情中脉冲按现行飞行激光显示“飞行接触”。

[下载离线HTML/SVG包 offline-reference.zip](offline-reference.zip)：供解压后直接打开index.html，不需服务器、网络或安装。当前环境的Chromium管理员策略阻止file://，因此双击路径未实测；包内资源已按断网上下文和解压目录逐项加载检查。只带交互源码、SVG、必要图片及子集字体/许可，不含20张整屏证据、任务日志、整个游戏或封存试验。[资源清单](offline-manifest.json) · [离线与小修检查记录](evidence/revision-offline-check.json)。重建包运行`python build_offline.py`（需Python fontTools），打开成品包无需这些制作依赖。字体子集仅用于此参考包，未替换游戏字体。四方向依旧没有美术批准或接入授权。
