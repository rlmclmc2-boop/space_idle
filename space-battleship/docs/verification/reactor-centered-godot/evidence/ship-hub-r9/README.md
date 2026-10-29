# R9 舰内反应堆返修候选

本证据随 `implement/reactor-centered-godot` 的当前提交固定；代码、无字舱室、驱动、日志和截图同版。当前候选仍待原审及整体组审阅，实机短路径成功不代表美术最终通过或已合 main。

无字舱室为 [`working-bay-eight.png`](../../../../../assets/ui/reactor/ship-hub-r9/working-bay-eight.png)，1254×1254，SHA-256 `6c6db9e0f2ebcf70561d090644b34fc49602dc653559065650a097b04af702ac`。它把底部三道厚切角槽收为连续浅米色承载带；原生哑光矩形键在这条带上提供“均分”、循环数量 `×1 → ×10 → MAX → ×1` 和唯一主操作“升级”。顶栏与右侧战场属整体组范围。费用图标沿用公共资源图集及原色调制。操作文字保留 Godot 原生，未烘入图中。

四设备保留舱内机械实体及向核心的玻璃管道。针对前版 `af5767bf` 的实图退回，铁产出读面的名称/倍率仍用 17/18px 字形；针对 `2775ecc0` 中倍率下沉的问题，两者现沿同一上倾读面基线排成一行。均分和购后 1× 均可完整读到 `铁产出  ×1.13`，文字上下留白均衡，末位不压象牙斜框。武器工作矩形从全屏约 x55–135/y204–269 取源，两根铜管各用与图中内表面一致的略下倾轴线；光限定在约 x63–116 的管身，右端在夹圈前渐隐，管间黑缝与支架不着色。盾甲光扫在原图已有的六角玻璃格内，不再叠绘另一套错位网；其立柱、下前唇仍是实体边界。实际工作强度只读取已生效 Owner load；零负载关闭，正低负载保留最低可辨亮度。铁散热器、碎片晶体、核心与进出管线继续按相同 Owner 来源工作。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`、Mesa llvmpipe，正式主场景 `1440×900`，1× 实图：[真零](reactor-r9-zero.png)、[均分后](reactor-direct-active.png)、[MAX 报价](reactor-r9-max.png)。[均分后内容区 2 秒短片](reactor-r9-flow.mp4)和[升级后低负载 2 秒短片](after-upgrade-flow.mp4)均由 12 个 Godot 帧以 6 fps 编码为 `808×836`，最后 1 像素是编码填充，无插帧。复现用[均分/光轨驱动](flow-driver.gd.txt)及[日志](flow-runtime.txt)、[鼠标操作驱动](operation-driver.gd.txt)及[日志](operation-runtime.txt)。驱动使用独立临时用户数据目录，通过公开 Campaign 恢复入口临时开放反应堆/凝聚，并通过公开 Economy 入账提供铀预算；它不证明自然关卡开放或收入。

[操作真零](operation-zero.png)、[滑杆后](operation-slider.png)、[×10 前](operation-ten-before.png)/[后](operation-ten-after.png)、[MAX 前](operation-max-before.png)/[后](operation-max-after.png)是同版原尺寸图。鼠标滑杆使武器 Owner 比例 25%→6%，直接生效。×10 成交使等级 1→11、铀 1000→450；MAX 重新报价后成交 11→12、铀 450→248。每次金额由 Amount API `from_decimal`、`sub_nonnegative`、`compare` 对当前钱包和 Owner 报价精确核对。当前 ×10 前后两张图的核心均无遮挡；`af5767bf` 版操作图曾出现临时“反应炉已解锁”引导，本版图像只证明这两个采集时刻的可见状态，不代表全流程的引导关闭已单独验证。

`--check-only`、两条当前短驱动及 `git diff --check` 通过。均分短片在记录前逐帧清理临时引导，日志记录工作相位推进；MAX 后四路 Owner 负载均为正、核心总负载约 0.00937，低负载短片记录工作层更新。这是本次受影响路径的短验证；反应堆内区限定视觉已获原审通过，公共组合、main 接入与目标硬件长期表现不在此结论内。本目录较早的 `cycle-*`、`inset-mouse-*` 是历史版本证据，不支持当前候选结论。
