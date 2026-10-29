# R9 舰内反应堆返修候选

本轮报价修复以本分支当前提交的[无钱图](quote-no-funds.png)、[可购图](quote-funded.png)、[驱动](quote-resource-driver.gd.txt)和[日志](quote-resource-runtime.txt)为同版证据。下述零供能、均分、购级与动态旧证据固定于 `4924205e`，保留其原审范围，不把它们写成本轮重新运行。反应堆内区已获限定审查；共享组合与 main 仍分别审阅。

无字舱室为 [`working-bay-eight.png`](../../../../../assets/ui/reactor/ship-hub-r9/working-bay-eight.png)，1254×1254，SHA-256 `6c6db9e0f2ebcf70561d090644b34fc49602dc653559065650a097b04af702ac`。它把底部三道厚切角槽收为连续浅米色承载带；原生哑光矩形键在这条带上提供“均分”、循环数量 `×1 → ×10 → MAX → ×1` 和唯一主操作“升级”。顶栏与右侧战场属整体组范围。费用图标沿用公共资源图集及原色调制。操作文字保留 Godot 原生，未烘入图中。

对照共享组合 `design/clear-zone-host@412d9d2f` 的实图，本版把底台上行“等级”标签移入浅米色净区，首字不再压左上深色斜切边；下行“已配／剩余”仍在原位置。成功报价的费用与数量保持深蓝，MAX 资金不足时将“MAX 可购 0 级”与橙色“资金不足”分成两个原生标签；有报价但不可购时原因同用装备费用行的橙色 `#a1593b`，金额仍按 Owner 报价显示。没有改变 Owner 的费用或 `can_purchase` 判断。

针对共享组合 `135db6fc` 的无钱图退回，固定数量报价只要 Owner `costs` 中有单一资源，就同时展示该资源费用、`ResourceVisuals.icon(id)` 实体图标及 `icon_modulate(id)` 原色，不以 `can_purchase` 控制图标。无钱 [1× 整屏](quote-no-funds.png) 中 Owner 报价 `10 铀`、`can_purchase=false`，橙色“资金不足”与铀图标、费用并列；同一会话公开 Economy 入账 1000 铀后的[可购整屏](quote-funded.png)仍显示同一费用和图标，`can_purchase=true`。两张图均为 Godot 4.7.2 正式主场景 1440×900 直接截图；驱动临时开放反应堆，仅观察受影响报价状态，不证明自然解锁或收入。MAX 可购 0 级时 Owner 返回空 `costs`，界面不伪造费用或图标，`cost_resource_ids` 订阅仍从 Owner 保留以便余额变化后重算。

四设备保留舱内机械实体及向核心的玻璃管道。针对前版 `af5767bf` 的实图退回，铁产出读面的名称/倍率仍用 17/18px 字形；针对 `2775ecc0` 中倍率下沉的问题，两者现沿同一上倾读面基线排成一行。均分和购后 1× 均可完整读到 `铁产出  ×1.13`，文字上下留白均衡，末位不压象牙斜框。武器工作矩形从全屏约 x55–135/y204–269 取源，两根铜管各用与图中内表面一致的略下倾轴线；光限定在约 x63–116 的管身，右端在夹圈前渐隐，管间黑缝与支架不着色。盾甲光扫在原图已有的六角玻璃格内，不再叠绘另一套错位网；其立柱、下前唇仍是实体边界。实际工作强度只读取已生效 Owner load；零负载关闭，正低负载保留最低可辨亮度。铁散热器、碎片晶体、核心与进出管线继续按相同 Owner 来源工作。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`、Mesa llvmpipe，正式主场景 `1440×900`，1× 实图：[真零](reactor-r9-zero.png)、[均分后](reactor-direct-active.png)、[MAX 报价](reactor-r9-max.png)。[均分后内容区 2 秒短片](reactor-r9-flow.mp4)和[升级后低负载 2 秒短片](after-upgrade-flow.mp4)均由 12 个 Godot 帧以 6 fps 编码为 `808×836`，最后 1 像素是编码填充，无插帧。复现用[均分/光轨驱动](flow-driver.gd.txt)及[日志](flow-runtime.txt)、[鼠标操作驱动](operation-driver.gd.txt)及[日志](operation-runtime.txt)。驱动使用独立临时用户数据目录，通过公开 Campaign 恢复入口临时开放反应堆/凝聚，并通过公开 Economy 入账提供铀预算；它不证明自然关卡开放或收入。

[操作真零](operation-zero.png)、[滑杆后](operation-slider.png)、[×10 前](operation-ten-before.png)/[后](operation-ten-after.png)、[MAX 前](operation-max-before.png)/[后](operation-max-after.png)是同版原尺寸图。鼠标滑杆使武器 Owner 比例 25%→6%，直接生效。×10 成交使等级 1→11、铀 1000→450；MAX 重新报价后成交 11→12、铀 450→248。每次金额由 Amount API `from_decimal`、`sub_nonnegative`、`compare` 对当前钱包和 Owner 报价精确核对。当前 ×10 前后两张图的核心均无遮挡；`af5767bf` 版操作图曾出现临时“反应炉已解锁”引导，本版图像只证明这两个采集时刻的可见状态，不代表全流程的引导关闭已单独验证。

本轮 `--check-only`、报价双态短驱动及 `git diff --check` 通过。`4924205e` 版的两条原短驱动记录：均分短片在采集前逐帧清理临时引导并推进工作相位；MAX 后四路 Owner 负载均为正、核心总负载约 0.00937，低负载短片记录工作层更新。目标硬件长期表现、公共组合与 main 接入不在本轮结论内。本目录较早的 `cycle-*`、`inset-mouse-*` 是更早历史证据。
