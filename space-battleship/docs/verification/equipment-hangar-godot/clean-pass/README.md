# 装备材质、长值与控件状态定向修订候选

固定运行源码 **318f5f342e8d44006e530f7f9501b517a3aab359**（材质主体f6a7098e加实际字体后尺寸修正318f5f34），原工作区 `/workspace/space_idle`、分支 `implement/equipment-hangar-godot`。供原独审复核5012视觉复看的两项阻断及补充状态反馈问题；不自判视觉通过，未合main。运行代码仍只改 `src/ui/equipment_panel.gd`，无main、业务、配置、battle或其他模块改动。

## 先看同版实图

- [正常巡洋舰/比较](candidate/03-cruiser-cannon-comparison.png)、[真实初始未解锁状态](candidate/01-starter.png)、[防御候选](candidate/16-defence-candidate.png)。
- [长MAX主值及完整两资源费用](candidate/19-long-max-multi-resource.png)、[批量真实部分成交](candidate/12-batch-partial-result.png)、[实际换装冷却](candidate/09-switch-cooldown.png)。
- 槽终端：[normal](candidate/21-slot-normal.png)、[hover](candidate/22-slot-hover.png)、[pressed](candidate/23-slot-pressed.png)、[focus](candidate/24-slot-focus.png)。
- 竖候选：[normal](candidate/21-candidate-normal.png)、[hover](candidate/22-candidate-hover.png)、[pressed](candidate/23-candidate-pressed.png)、[focus](candidate/24-candidate-focus.png)。
- 普通数量键：[normal](candidate/21-quantity-normal.png)、[hover](candidate/22-quantity-hover.png)、[pressed](candidate/23-quantity-pressed.png)、[focus](candidate/24-quantity-focus.png)。

全部图为真实Godot 4.7.2主场景根视口1440×900原像素，未裁切、缩放或拼接。截图及JSON/hash见 [manifest.json](manifest.json)，操作原始数据见 [candidate/operations.json](candidate/operations.json)，原驱动/日志在本目录。

## 实际修法

**不同尺寸材质分开。** 原2059×640宽PNG机壳已退出所有运行控件，不再NinePatch挤入62×41数量键、58×28卸下或65×89候选。槽终端使用新建干净SVG：220×82，连续干净轮廓、象牙装甲面、深蓝底座与空青蓝屏，底socket中心(110,73)直接接原支承；原support-arm.png、正式舰体/武器及其挂点不变。普通按钮用简洁横向native材质，竖候选有单独薄壳比例；没有把宽纹理转竖拉伸。批量面板也用独立简洁面材。

SVG为新写的几何/渐变源码，不是脚本清洗旧PNG。实际先调用ImageGen清理原图，但输出仍有轮廓外碎白点，检查后未采用；原输出保留，路径/hash及决定见 [素材来源](../../../../assets/ui/equipment/hangar/sources.json)。旧PNG保留来源，不代表仍加载。没有对正式舰体、武器、防御图标或其他模块做重制。

**长主值给空间。** 字体实测宽度超原148/140px时，只把左台的“当前/升级后”主值改为上下两行，各222px宽；字号27、两列候选比较及费用区不变。实际长MAX“1.556×10^43”墨迹宽176，起点x232、右缘x408，距金属分隔x478约70px；主值Label下缘713，费用标题起点714，未侵入费用。原所有者完整主值 `1.55622014967727e43` 保存在可悬停的值Label tooltip，UI没有重算数值或报价。费用继续完整显示 `1.145×10^39`铁及2730简并物质，金额字号17未缩。

**状态字和交互表面。** 已装备/待安装/未解锁采用11px、600轴半粗，实际矩形(3,68,59,17)，卡65×89，底部4px净空；标题区(3,48,59,20)与状态区不重叠。修正了Label在设字体前曾被默认字号撑高、之后不自动缩回的初始化尺寸问题。实际字体最小高度17，不能仅凭请求size17宣称净空。

每按钮初始化两组（普通/选中）normal/hover/pressed/disabled/focus样式。悬停提亮、按下压暗及降低底部厚度、焦点青色轮廓、禁用降对比并保留必要状态名；空text的槽/候选同样有材质反馈。选中只切已有样式，无全量样式重建。实际鼠标InputEvent获得native draw_mode normal0/hover2/pressed1；焦点取证由Control.grab_focus()建立实际Control焦点，未冒充一次完整键盘导航验收。初始真实进度下舰炮disabled、draw_mode3、“未解锁”状态可见。三类控件各10个缓存StyleBox的交互前后资源ID相等。

400/600数值轴及字体资源保持前版，未扩大修改共享字符串wght/embolden；基础TextServer metadata仍100。原 [真实栅格与指标](../visual-pass/font-raster.json)继续区分400/600实际字形，当前真实卡状态字体/尺寸与正常画面另在本版JSON和PNG中体现。

## 原操作与四项正确保护

同版操作检查 `EQUIPMENT_CAPTURE_COMPLETE failures=0 records=19`：原14条状态/业务记录加真实禁用、三类交互状态和长值几何记录。武器与防御均实际+1/+10/MAX，每笔用原Amount核钱包减actual spent及等级增量等于实际count；候选浏览不安装、真实换装锁拒绝与游戏时间到期、资源不足所有者拒绝、批量部分成交/底层阻挡/关闭重开保持均通过。巡洋舰/进度100/付费等级及钱包是记录清楚的受控save-state restore和实际native refit，不冒充自然赚取进度或个人存档；没有假报价、假业务响应或UI金额公式。

[四项定向原始记录](regression/runtime.json)/[日志](regression.log.txt) `failures=0`：

- 活战斗game_time3.1667→4.7667，96次经济通知、钱包不变，槽位/选项/比较/MAX读取均0；仍64次battle draw及4次正常统计更新，节点增删0。另一个定时移动1.60游戏秒窗口亦96通知/0读取。
- 原舰桥反应炉实际免费分配武器80、防御20，各恰1条comparison依赖通知，current/upgrade/candidate实际改变并等于所有者，无额外装备点击刺激刷新；这里只回归既有接口，没有实施反应炉或宿主改动。[武器](regression/free-weapons-return.png)/[防御](regression/free-defence-return.png)。
- 原632×900右区域保持scale双轴0.9375、投影(855.875,0,536.25,900)。真实已生成拥有金额的掉落，仅经验证受控保存将位置置于逻辑x32/540，实际根坐标点击移除且Amount核钱包；左空白边带误点不拾取。[左前](regression/edge-left-before.png)/[后](regression/edge-left-after.png)、[右前](regression/edge-right-before.png)/[后](regression/edge-right-after.png)。
- [未知回执](regression/batch-unknown.png)仍明确未确认，不显示等级保持或成交后余额；rejected/not_submitted/accepted缺明细也不从空数组推断0成交。这些是实际Control的呈现边界输入，不伪造native致命故障/财务执行；正常部分成交另有真实所有者回执。

## 失败轨迹与边界

新增完整值tooltip最初遗漏MAX耗尽时合法null升级预览，导致刷新脚本错误并漏掉一次冷却显示断言。原 [失败操作JSON](before-null-tooltip-fix/operations.json)及 [错误日志](before-null-tooltip-fix/runtime.log.txt)保留；该进程结束前源码文件已补空值守卫，因此其文件hash不能冒称已加载脚本，**整轮不绑定为固定源码通过证据**。修正后先得到f6操作/回归0失败，再从实际矩形发现状态Label仍高24px；重设施字后的尺寸后，最终318f完整操作/原四项都重跑并0失败。中间完整图保留本地 `before-null-tooltip-fix/`、`pre-status-size-fix/` 与 `preview/`，不当正式同版图。上一轮误复用受控存档的恢复暂停失败仍在原visual-pass/regression-recovery-window，不覆盖删除。

所有本版进程使用新的独立/tmp设置/存档目录，启动断言无recovery暂停；原Godot/native/config环境复用 [environment.md](../environment.md)，无重搭环境。原始source_hashes与固定Git对象逐项核对在manifest；本次两个正式runner均有完整318f源标签，且哈希相等。

未覆盖全舰型/全部长值组合、完整键盘导航、长期性能、Windows/DPI及其他模块。新简洁材质是否达到图04的空间与设备感、实际状态对比强度仍待原独审，不以文件干净/断言通过代替视觉通过。当前无环境、审批或外部写入阻塞；执行者 `/root/equipment_visual_replacement` 未实际上下文压缩，固定交付后不接新批。
