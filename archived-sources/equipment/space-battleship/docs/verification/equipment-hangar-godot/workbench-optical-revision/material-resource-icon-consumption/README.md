# 装备费用/余额保留材质资源图原色（待原审）

固定源码 `243b24a199f6eb5757a6ddd5118052c8eb5a4f8f`，前版 `6829c44af95b4ded820e84b34623c65caf3a7380`。只修资源图消费窄项，标题切角源码d034de07及当前266/288px工作台保留，信息组织仍[仅提案](../header-inner-chamfer/information-layout-proposal.md)，本轮未实施压缩或新窗。

来源正常fetch `origin design/clear-zone-host`，精确解析整体固定对象 `da018a65cbf52eda9cbea0db4dcf640c09b4da86`。当前原装备helper还是c4时期SVG版本，唯一 `_resource_icon` 同时服务费用20px和余额17px、直接调用color(id)；若接入新彩色PNG仍保留该调用，会整幅RGB乘语义色变暗。现在精确提取da018a65的resource_visuals.gd、其实际resource-material-atlas.png/import以及原prompt/source-json，共五文件逐字固定对象；13仅替换§2.2资源身份一段，没有整合公共壳或其他页面。既有jewel/matter SVG字节未变；旧铁/铀/chrono SVG保留历史文件，本helper不再消费它们。

装备消费仅改一处 `mark.modulate=ResourceVisuals.icon_modulate(id)`。铁/铀/时空微粒按helper白色保原图，强化碎片/简并物质仍按helper原线图语义色；文字/其他颜色、价格、数量和刷新路径不变。helper将实际图集边界初始化处理成24×24透明图标并按ID缓存；本页沿用20px费用和17px余额TextureRect，不在刷新时裁图或创建节点。未接反应炉、战场或宿主。

## 本页真实小尺寸图

[完整整屏](01-material-fees.png)、[原像素工作台](01-material-fees-local.png)、[实际费用400×52原像素局部](01-material-fees-costs-local.png)全部实际view_image，未经放大、补绘或拼图。来源是当前main.tscn/Session/native的Lv19受控静态双费：铁1600、简并物质10；图中下方费用处的铁保留橙金属原色，邻近名称与金额可辨，标题沿内壳切角保留。顶部余额显示不是本页费用通过的替代证据；没有铀/chrono生产费用，所以不伪造这两种消费行或第三费用。此项作者观察仍交根/原Astra判断。

[mapping.json](mapping.json)记录实际5资源缓存的20/17px尺寸、texture图像像素hash、alpha已用边界、modulate/self_modulate、父节点调制和当前真实quote。三材质缓存费用/余额modulate均ffffffff、父节点白色；两SVG仍其helper语义色，所有资源费用/余额同Texture2D。铁原缓存24×24、已用22×17，显示在20px控件内可见约18.33×14.17px；保留这一实际尺寸边界，不把控件20px冒称主体也满20px。铀和chrono费用缓存存在但不可见，本记录只证明映射消费正确，不称本页真实费用实看。

图集SHA256 `5ac83cda22d7e7e57beb6e8d20ae6c20e1353a5e2b8c0430f97e404a750dc8ec`，helper SHA256 `4c4cba630f027319ceb6d6aa345bcdc886873d130bc2165e9a83718f54f7fc4f`。裁切边界/原生成来源/prompt全部随固定来源原字节复制；无新资产生成或重绘。详细路径hash及“除单一消费调用外equipment_panel整文件逐字前版”的核对见[source-boundaries.json](source-boundaries.json)。这同时保住标题、两键、Owner、精准刷新和整个未改主布局。

Godot4.7.2 check-only通过；最终固定源码后静态采图进程exit0，`EQUIPMENT_MATERIAL_RESOURCE_STATIC_COMPLETE`，不执行购买，不重跑旧36或新增全链/独立矩阵。首轮driver的占位字符串替换误伤RESOURCE_NAMES，在截屏后映射读取失败；原driver/log原样保存first-driver-typo，仅修driver后正常完成，运行源码没有为此改动。不把首轮失败当通过；旧采图也留/tmp。

运行源码/非raw文档diff-check通过；Godot原始check.log尾空行原样保留。无权限阻塞，无运行任务，本SOL截至本项归档未实际上下文压缩。原唯一workspace/美术分支/cache/未跟踪/import/UID/tmp/原图全保留；只普通推本非main候选，不main/Library/Space/新任务/子代理。整体艺术/完整状态矩阵/自然收入/额外生产费用未扩大结论。
