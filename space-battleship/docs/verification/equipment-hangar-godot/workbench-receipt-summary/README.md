# 装备对象梁短回执：单项修正候选

固定运行源码 `5f1605ffd42bac5c45af3357073d36935f6888ce`，原目录 `/workspace/space_idle`、原分支 `implement/equipment-hangar-godot`。本次只修dc7购买后对象梁回执从半句开始的问题；保留已改善的整台重排和未解锁纯空位。无新布局批次、无全套复测、未合main、未访问Library/Space，仍交根严格审查。

**根因：** 原反馈Label只有262px宽，完整两行回执被拼成一行后使用右对齐和clip_text，长消息左部被截掉，所以只剩“10简并物质 · 实际花费…”；字号或实际交易没有问题。原Label还继承MOUSE_FILTER_IGNORE，虽然tooltip文本存在，悬停不易触发。

**修正：** 对象梁使用由真实accepted回执的slot_id/count生成的短句，本次实际为“武器1 · 购级完成 +1级”。详情仍逐字使用原 `_receipt_text`，保留原spent及完整消耗；单笔短句不复制费用长串，多槽摘要仅报实际购买槽数。左对齐加尾省略保留句首，12px字号和262px栏宽不变；反馈Label改为MOUSE_FILTER_PASS，实际悬停可查原回执。`last_result`深拷贝、dirty/command_finished、Owner、付款和count/spent全部不改。

## 同版真实图

以下是固定提交后真实Godot4.7.2/main/Session/native、1440×900/左808×900同一次进程的两张整屏；两张整屏及两局部均已实际view_image核看。

- [实际购买后整屏](01-actual-purchase-short-receipt.png) / [完整短回执局部](crop-complete-short-receipt.png)：对象、完成与+1级从头到尾可读，不再半句开头。
- [真实悬停整屏](02-actual-receipt-tooltip.png) / [完整消耗tooltip局部](crop-original-detail-tooltip.png)：显示“武器1 +1级 · 1,600 铁 / 10 简并物质”和原“实际花费”行。

局部仅作原像素裁切，无缩放/重绘/拼贴；源图、坐标及全部文件SHA见[manifest.json](manifest.json)。受控进度/钱包/weapon19用于这一笔双资源购买，不冒充自然开放/赚取。设置/存档/缓存不入Git。

## 必要操作与证据范围

[实际驱动](capture-driver.gd.txt)、[完整结果](operations.json)、[日志](capture.log.txt)：进程exit0，`WORKBENCH_RECEIPT_COMPLETE failures=0`。仅一笔真实GUI+1购买及真实悬停，不重复7状态/四保护。

- 真实accepted回执一个purchase、count=1，武器Lv19→20；逐资源以原spent核对钱包精确相减，铁100000→98400、简并物质1000→990。
- 短句实际字体宽125px，小于栏宽262px，字号12保持；不靠缩字或增加控件宽度塞入明细。
- 原详细tooltip逐字等于原 `_receipt_text(last_result)`；真实鼠标悬停后可见PopupPanel/Label节点及完整文字均记录在operations，整屏也实际看过。
- [静态保护依据](preserved-boundaries.json)确认相对dc7的14个布局/候选/刷新/命令/详细回执函数和7个宿主/业务/战场/拾取/几何文件逐字节相同。仅对象梁控件属性、短句函数及显示赋值改变；原布局、未锁空位、U1与Owner均保持。

本次只支持此笔成功购级的短句与完整悬停明细。多槽摘要、未知/失败结果未新增运行案例；停机/其余三档和完整配装净空、全V0/V2、长期性能、Windows/DPI边界继续保持，未扩大通过。当前无运行任务、未实际上下文压缩。普通Git推送，只交根审，不向用户发中间候选。
