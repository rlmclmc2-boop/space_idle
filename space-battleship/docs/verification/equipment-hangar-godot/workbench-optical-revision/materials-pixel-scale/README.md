# 装备材质退回后：实际像素尺度与动作层级候选

`ba7afb24/c6e54749` 美术已由根实图及原Astra退回，不能作为达标基线；其循环数量逻辑和操作组关系保留。当前固定源码 `f1a16bf6b59aab2005da89ff3062f316e807849a`，原分支继续，待原审，不pushmain。用户此前main功能认可不等于美术通过。

## 本次逐项修正

- **跨比例纹理：** 停止加载原四象限atlas；新增一张无边/无宏观高光/无方向刷痕的1254×1254细哑光涂漆金属源。EquipmentSurface原生StyleBox以canvas_item_add_texture_rect(tile=true)在实际屏幕像素尺度采样，**没有resize、九宫格边缘缩放或整面拉伸**。大小控件使用相同的实际像素微粒尺度，纹理以12%混合在均匀底色上；不会把小样板放大成批量刷纹或把整图压成标题横纹。
- **实际边界：** 上/下1px边光在每个真实Control rect内原生绘制，颜色从实际底色轻微增亮/减暗计算，不来自图片的边框。无额外贴片、花边或旧SVG叠层；关闭弱动作不画边。首轮实际看图发现全强度颗粒仍显眼、读数顶线过白，随后仅将原生混合收至12%并按底色算边光；未生成第二批素材。原预览/tmp/equipment-material-v2-preview保全。
- **顶栏与局部梁：** 撤回本次对公共顶栏的材质覆盖；equipment::_draw逐字回到main该函数，不改main/全局导航。装备局部对象梁继续冷色金属，但不压缩任何纹理/高光条。
- **读数/报价：** 报价的独立浅绿底完全撤掉，直接落在统一工作台面；读数只保留低反差冷灰承托，无浅绿反光/白亮条，原字号/字形/数值位置保留。
- **动作层级：** 购买/安装/批量执行为暖金属主层、深色原生字；数量模式为冷灰次层；关闭使用接近面板的弱层与浅灰字，仍保留原点击区域/原生hover/pressed/focus。按角色缓存原生样式，不改按钮信号或命令。

新素材[PNG](../../../../../assets/ui/equipment/materials-20261029/satin-metal-tile.png)、[完整提示](../../../../../assets/ui/equipment/materials-20261029/satin-metal-prompt.txt)、[来源/hash](../../../../../assets/ui/equipment/materials-20261029/satin-metal-sources.json)。实际工具image_gen.imagegen，原文件/workspace/generated_images/exec-27e5f04b-1c85-4571-a215-a3621ed0b2d7.png保持；PNG SHA256 `c2462500cf121ada48fd91e6ef2829eb1cb2a6f7aadd57a75e19f023894c2a3b`，提示SHA256 `4e47ac6ff88bfa52fcb593a07658205835f89d2c438813d551c695a6aee5cd53`。原atlas及提示仅留历史来源，不再消费。没有烘文字/数值，没有替换正式机库/舰船/武器身份。

## 同版真实整屏与原像素局部

正式main.tscn/Session/native Godot4.7.2、1440×900窗口/808模块，复用原环境和缓存，独立临时设置/存档。解析exit0、实际采图进程exit0，无脚本/资源错误；`MATERIAL_PIXEL_SCALE_CAPTURE_COMPLETE failures=0`只说明启动及取图完成，**不是新功能全测或美术通过**。本次没有重复循环/购买或新增全链测试。

| 静态状态 | 原尺寸整屏 | 原像素局部 |
|---|---|---|
| 新局/资源不足/禁用主购买 | [整屏](01-normal.png) | [局部](01-normal-local.png) |
| 真实Owner双资源报价/主购买/次模式 | [整屏](02-double.png) | [局部](02-double-local.png) |
| 异物候选/比较/主安装 | [整屏](03-different.png) | [局部](03-different-local.png) |
| 批量当前槽/次模式/主执行/弱关闭 | [整屏](04-batch.png) | [局部](04-batch-local.png) |

4整屏及4局部全部已实际view_image查看。局部由同一Godot根视口Image按真实workbench/Batch rect扩8px直接get_region，不缩放/重绘/拼贴；[坐标与取图记录](observations.json)。[驱动](capture-driver.gd.txt)、[原日志](runtime.log.txt)、[解析日志](check.log.txt)、[manifest](manifest.json)保留。Lv19/解锁/预算仍为公开restore与发布口受控准备，不代表自然成长。

## 保留与未覆盖

[源码边界](source-boundaries.json)记录16个初始化/循环/Owner调用/报价布局/精准刷新/独占/几何函数逐字ba7；equipment::_draw逐字main，main/Session/Equipment/Economy/CampaignView/project及正式机库/船武器manifest/几何文件逐字main。当前循环语义、独立购买、Batch独占/force、无记录最近结果、未解锁纯空位、冷却与等比输入不重开。先前ba7循环32项证据仅保留其原始版本，不冒充本材质重跑；旧动态也不作为当前材质视频。

当前只修材料尺度、边界与主次，对照实图供原Astra/根判断；不自行判艺术通过。未新采动态/全舰满装/极端1e39新布局/Windows-DPI/长期性能/全保护/完整保存替换；真实第三费无生产来源，仍不造fixture。无业务/宿主/配置改动，不新增任务/代理/工作区，不Library/Space，不pushmain。未实际上下文压缩。
