# 装备工作区结构深度候选：待原审

根实图与原Astra已退回 `38603c36` 的整体质感；其解决拉伸纹理、绿亮片和主次的限定改进保留，不能写成艺术通过。当前固定源码 `75782d9461b46a544abdd116f31baed65e720b99`。继续原分支/原工作区，不重开已认可的循环、报价操作组或业务，不pushmain。

## 从机库结构到实际承托

本轮重新实际查看386整屏/工作台与批量局部，对照原机库台面环形上缘受光、侧缘暗部及底座接触。当前不再靠纹理或换色表示厚度，而在同一EquipmentSurface原生StyleBox中绘制一个结构截面：

- **整台单壳：** 实际左右6px折边、顶部4px落面、底部8px前侧面与1px接触暗缝。侧面多边形连接承载面/前侧面，外角做同截面折角，不绕台体堆第二圈装饰框。底前侧面落在原台体bottom896内，与原背景相接。
- **对象梁：** 与台壳同一薄截面，4px下侧面承接台面；没有压缩图片或烘焙的反光横条。
- **读数/图标/候选：** 3px内凹口，顶部/左侧阴影和下侧金属回边让内容成为台面中的凹嵌位/匣座，保留原图与原生字。没有单独绿色高光片，也不画多层粗边框。
- **原生按键：** 普通主/次数量键以4px前侧面形成浅行程；pressed收成1px前侧面、承载面下落2px。原生字的top/bottom内容余量3/7→6/4，总和仍10px，不改变控件尺寸。主购买/安装/执行暖金属、模式冷灰、弱关闭的层级保留；弱关闭不加凸起壳。
- **批量同体系：** 原628宽/按槽数高度的窗口使用同一单壳截面，当前槽/数量/执行/关闭布局不变。不是把小面图片放大成刷纹背景。

表面四顶点只作低幅受光（顶左+4%、顶右+1.5%、底右−2.5%、底左−1%），方向与机库一致；不是拉伸一条高光贴图。所有面/侧面/凹槽按实际屏幕rect计算、在原Control rect内绘制，无expand_margin或外扩阴影。报价/按钮间距、字形布局与点击区域保持。[精确截面数值](structural-profiles.json)及[源码边界](source-boundaries.json)可核。

## 同版真实整屏与局部

正式main.tscn/Session/native Godot4.7.2、1440×900根窗口/808模块；复用原环境/缓存，临时独立设置/存档。解析exit0，静态采图进程exit0，`EQUIPMENT_STRUCTURAL_DEPTH_CAPTURE_COMPLETE failures=0`。这里仅说明启动/取图，不宣称功能全测或艺术通过。

| 状态 | 原尺寸整屏 | 原像素局部 |
|---|---|---|
| 新局/不足/禁用 | [01](01-normal.png) | [局部](01-normal-local.png) |
| 双资源报价/主购买/次模式 | [02](02-double.png) | [局部](02-double-local.png) |
| 异物凹嵌候选/比较/主安装 | [03](03-different.png) | [局部](03-different-local.png) |
| 批量同壳/模式/执行/弱关闭 | [04](04-batch.png) | [局部](04-batch-local.png) |

4整屏+4局部及[真实按下局部](05-primary-pressed-local.png)全部已实际view_image查看。按下由原生鼠标输入取得，draw_mode=1；随后移出并释放，未执行购买，后续原图等级仍Lv19。局部由同一根视口真实像素get_region，扩边与1440×900交集取裁区，不补黑边、不缩放/重绘/拼贴；[记录/坐标](observations.json)。[驱动](capture-driver.gd.txt)、[原运行日志](runtime.log.txt)、[解析日志](check.log.txt)、[manifest](manifest.json)。

作者在原尺寸/局部辨认了侧面接触、凹槽、普通与pressed前侧面/字位；报价与操作外沿未被越界绘制侵入。本轮未新增交易/循环或全链复测，不把旧ba7的动态/32观察写成本轮实测。解锁、Lv19、预算仍是公开restore/发布口的受控准备，不证明自然成长。

## 来源与边界

本轮没有新生成素材批。继续使用原[细金属PNG](../../../../../assets/ui/equipment/materials-20261029/satin-metal-tile.png)、[原完整提示](../../../../../assets/ui/equipment/materials-20261029/satin-metal-prompt.txt)、[原生成来源](../../../../../assets/ui/equipment/materials-20261029/satin-metal-sources.json)，原文件/workspace/generated_images/exec-27e5f04b-1c85-4571-a215-a3621ed0b2d7.png保留。PNG SHA256 `c2462500cf121ada48fd91e6ef2829eb1cb2a6f7aadd57a75e19f023894c2a3b`，提示SHA256 `4e47ac6ff88bfa52fcb593a07658205835f89d2c438813d551c695a6aee5cd53`。原来源文件中1px平面runtime描述属于f1/386历史；当前新增侧面/支承几何为本轮Godot原生源代码，见本页profiles与源码hash，不冒称新imagegen边框。细纹理仍原像素tile/12%混合，不承担结构几何，不烘文字/数值。

16个初始化/循环/Owner调用/报价布局/精准刷新/独占/几何函数逐字386；main/Session/Owner/Economy/Campaign/project/正式机库与manifest/共享几何逐字main；equipment::_draw逐字main。公共顶栏/宿主/正式船武器未动，未锁纯空位、无记录最近结果、冷却和原生当前状态继续保留。所有运行变化仅equipment_panel美术截面及其native字位。

厚度、凹嵌、边缘克制与整机库的视觉关系仍待原Astra/根判断，不自判艺术达标。未新采动态/极端长金额/全舰/WindowsDPI/长期性能/完整保存/全保护；三资源无第三真实费用，不造fixture。不新工作区/代理/任务，不Library/Space，不pushmain。未实际上下文压缩。
