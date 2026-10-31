# 装备费用同步完整五资源材质家族（待原审）

固定源码 `723ec0ed924e923b19ef9d95552c22382d3040ba`；固定共享来源 `08e23a1cbca396b3c0ccb4765d43ad034e0c8c20`，正常fetch `origin design/clear-zone-host`读取。前版源码243b24a1/证据1354d2bb保留原版本图与记录；本次仅同步完整资源家族，当前结构266/288、原生字号、标题切角、两键/Owner/精准刷新未变，[重排/展开/压缩提案](../header-inner-chamfer/information-layout-proposal.md)继续仅历史存档、非待执行。

新同步必要文件：`src/ui/resource_visuals.gd`、`assets/ui/public_shell/resource-material-supplement.png`及其import/source-json/prompt，共五文件逐字08e23a1c；前三资源的既有atlas四文件核对同一固定来源字节一致，未重制。13仅精确替换§2.2资源身份一段，没有覆盖整份规范或接入公共壳/宿主/反应炉/战场。

helper现在五种ID均为实体材质：铁/铀/时空微粒继续原atlas，强化碎片/简并物质来自同源supplement的紫晶片/银蓝致密球。装备原 `_resource_icon` 已用icon_modulate，**equipment_panel整文件没有一字修改**；五种都由helper返回白色调制保原色，color仅保语义色用途。旧线SVG文件只保历史，本helper不再引用。没有新资产生成、另画同资源或新增刷新路径。

[完整整屏](01-material-fees.png)、[工作台原像素局部](01-material-fees-local.png)、[本页实际20px费用原像素局部](01-material-fees-costs-local.png)全部实际view_image。当前真实报价铁1600/简并物质10，在下方本次费用同列显示：铁锭和银蓝球均有体积/材质，原混搭简并线稿已换为实体，名称和金额净空保持。未用顶部余额图替代本页核对；原受控Lv19/availability/钱包fixture只用于静态画面，不证明自然生产。本页没有强化碎片、铀或chrono生产费用，不造对应费用或第三费图。

[mapping.json](mapping.json)记录5资源费用20px/余额17px、24px缓存图像及alpha边界/像素hash、同Texture与调制。五种fee/balance modulate均ffffffff，父节点白色。简并缓存24×24、已用22×20，在20px控件内实际可见约18.33×16.67px；不把控件尺寸当可见主体满尺寸。jewel缓存也换实体且调制正确，但本次费用不可见，不能冒称真实费用视觉通过。

补充图集SHA256 `39d511b72b17a67616b10647b3494c3914cb2f1ab14141cc17c52031223562d3`；helper SHA256 `1cae88972f1f5ce6f5a1793fcbadb24f9f978c2587855e59c28d4a964c4c0080`。原atlas仍 `5ac83cda22d7e7e57beb6e8d20ae6c20e1353a5e2b8c0430f97e404a750dc8ec`。九项共享源/资产原字节及equipment/main/Owner等不变核对见[source-boundaries.json](source-boundaries.json)；装备SHA仍 `81428e7c1837ca7e6fca66867123bdd0cad9b3a3976a24ddc9afe0f27bc0411c`。

沿用上一静态驱动，仅换本项目录与固定版本绑定，Godot4.7.2/main.tscn/Session/native同版一次exit0，`EQUIPMENT_FIVE_RESOURCE_FAMILY_STATIC_COMPLETE`。无购买、无36重跑、新独立复测或交易全链；旧36仍只属于89ac5d0a，同预算未新测。4.7.2 check-only及非raw源码/文档diff-check通过，原Godot check.log尾空行原样保留。图片/日志/源码绑定不替代根与原Astra的本页艺术判断。

本SOL截至归档未实际上下文压缩；原唯一workspace/分支/cache/未跟踪/import/UID/tmp/旧源图全部保留，无运行任务或阻塞。普通push非main，不Owner/main/公共壳/Library/Space/新任务/子代理。当前同步窄项供原审，不继续归档提案或自发扩测。
