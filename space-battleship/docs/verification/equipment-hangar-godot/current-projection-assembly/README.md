# 当前固定投影：中间三档与Heavy真实满装补证

固定运行源码 `551a4f2b0262b9f8291bb6a13b024c32a37ea341`，补证起点 `da317ba436a8fb4665b99d7d78cbf42e23f43bd3`；原目录 `/workspace/space_idle`、原分支 `implement/equipment-hangar-godot`。运行文件SHA256 `0d4d043bb814f39fffeebab1fa376f139d66ecf9e979b04ae5cdaea8a1482c51`，本次**没有改运行源码/正式资产/业务/宿主**。

根转报唯一独立Astra高审核：整台密度、未解锁纯空位、去防御贴片、完整短回执、刷新与H1模块端口等限定项可闭合，未确认P1/P2。本项只补原目标遗留的当前投影证据：此前只有小舰/非满装Heavy，旧投影五档不能替代。没有重开已审项、全套测试或新设计方向；本批停车关系与代表装配仍交原审，不从数值零失败推定整体视觉/V0/V2通过。

## 实际Owner装配与整屏

一次当前正式main/Session/native/Godot4.7.2进程，固定1440×900、装备808×900；下列5张真实整屏及5张同机位原像素局部均已实际view_image核看。不是生成图、前端假配装或图像合成。

| 代表状态 | 实际活跃武器（按Owner索引） | 实际逻辑防御 | 真实整屏 / 同机位局部 |
|---|---|---|---|
| Destroyer | 脉冲炮、导弹 | 护盾 | [整屏01](01-Destroyer-formal-full-active-assembly.png) / [局部01](crop-01-Destroyer-formal-full-active-assembly.png) |
| Cruiser | 脉冲炮、导弹、长激光 | 护盾、装甲 | [整屏02](02-Cruiser-formal-full-active-assembly.png) / [局部02](crop-02-Cruiser-formal-full-active-assembly.png) |
| Battleship | 脉冲炮、导弹、长激光、舰炮 | 护盾、装甲 | [整屏03](03-Battleship-formal-full-active-assembly.png) / [局部03](crop-03-Battleship-formal-full-active-assembly.png) |
| Heavy | 脉冲炮、导弹、长激光、舰炮、脉冲炮 | 护盾、装甲、护盾 | [整屏04](04-Heavy_Battleship-formal-full-active-assembly.png) / [局部04](crop-04-Heavy_Battleship-formal-full-active-assembly.png) |
| Heavy第五武器实际选中，导弹仅浏览 | 同上完整5武器不变 | 同上完整3防御不变 | [整屏05](05-Heavy-full-outer-weapon-locator-alternative.png) / [实际武5定位局部05](crop-05-Heavy-full-outer-weapon-locator-alternative.png) |

每舰先调用真实 `Campaign.change_ship(ship, commit_ship_refit)`；新增或不同类型只通过真实 `Equipment.equip_slot(..., publish_equipment_refit)`安装。共4次真实换舰、7次真实装备安装，均Owner接受，7次安装各引发1次native configuration_commit；`operations.json.preparation`保留每笔返回和前后提交计数。每张捕获读取真实Owner facts，并检查所有活跃槽非空、数量匹配正式舰型；未写panel._facts/装备ID/paid_level或假建渲染组件。右战场也随真实换舰/换装呈现相同正式装配，没有改其投影参数。

受控准备只包括开放进度100、钱包和Owner保存状态中的switch_ready_at清零，以准备可操作的展示状态；没有伪称自然赚取/开放。新安装后的真实10秒冷却仍保留，故第五张安装动作正确显示冷却中；仅选择/浏览，不再次安装。防御实际装入Owner与native容量，但继续无可见伪物理贴片/挂点。

## 当前投影、实际可见包络与净空

正式UI舰PNG的alpha边界、正式武器PNG/manifest锚点及当前同源变换构成可见包络，不用768px画布当舰体，不额外fit各舰。公开Battle.mount_inputs参考高仍导出166.115/234.463/265.635/320px的本批四档递进。

机库固定源y0..845→装备y85..685；源台面前侧线候选点(594,730)映为(404,603.3432)。每舰可见alpha舰尾落在该同一展示点。舰体、正式武器、选择框仍用当前同源比例；没有改战场、native挂点或正式资产。这个对应由真实图的台面/舰尾关系与数字共同供原审，不以等式宣布正确停靠。

| 代表 | 舰体可见W×H（px） | 含选中框/徽标包络x,y,w,h（px） | 到实际工作台顶（px） | 到侧索引右沿208的水平净空（px） |
|---|---:|---|---:|---:|
| Destroyer | 118.288×166.115 | 344.856,437.228,118.288,166.115 | 74.657 | 136.856 |
| Cruiser | 178.883×234.463 | 314.559,367.231,178.883,236.112 | 74.657 | 106.559 |
| Battleship | 233.698×265.635 | 287.151,337.708,233.698,265.635 | 74.657 | 79.151 |
| Heavy武1 | 272.027×320.000 | 267.986,283.343,272.027,320.000 | 74.657 | 59.986 |
| Heavy武5/异物比较 | 272.027×320.000 | 267.986,283.343,272.027,320.000 | 28.657 | 59.986 |

前四张真实同物台顶y678；第五张通过实际点击武器5再浏览导弹，真实展开264px异物台、台顶y632。Heavy最靠下武器的描边/完整“武5”徽标仍可见，未被台体吞掉；该浏览不改Owner slots/native提交/钱包。每个正式manifest挂点经当前画布变换后与实际 `_mount_position` 距离<0.001px；各实际组件可见alpha框、所选目标、徽标、船身和上述精确余量在[测量数据](measurements.json)及[原记录](operations.json)。

本批指定武器可见框全部包含于相应船身外接框；Cruiser选框上沿另伸出约1.650px，故标记包络高236.112px。包络是alpha外接框并集及当前标记，不是实际可见面积，也不包括细定位线从侧索引出发的整段路径；定位线/身份由整屏05实际核看。所有局部统一取原整屏(224,250,360,382)，同机位不缩放、不重绘、不拼贴、不另加假标记。

作者逐张看图：舰体/装配体量依次增大，舰尾保持同一台面前侧位置；无与侧索引、下方台体的遮挡/裁切，Heavy满装和武5实际选择可辨。未发现需要改源码的控件位置问题，因此保留551a。大型舰向停机台后方/上方机械空间延伸的停驻构图是否满意仍由根/原审判断，不把“包络未碰UI”扩大为物理停靠或完整美术通过。

## 证据固定与尚未覆盖

[原执行驱动](capture-driver.gd.txt)、[完整日志](capture.log.txt)：进程exit0，`CURRENT_PROJECTION_ASSEMBLY_COMPLETE failures=0 records=5`。只有这5个代表状态；没有组合枚举、全朝向、购买/四保护/H1整屏集成重跑。原运行5张原图及局部都同551a源码SHA；[源码/正式资产绑定](source-and-assets.json)核对20项源码/正式图/manifest与该固定Git对象一致，未交付generated/config或native产物。文件SHA、裁图坐标见[manifest.json](manifest.json)。

旧同投影小舰图仍是[a1fa的新局Frigate](../workbench-state-reflow/01-fresh-same-single-blank-locked.png)，没有篡改成551a图。本次校核a1fa与551a的8个初始化/投影/部件/定位函数逐字节相同，支持投影连续性；本批不假称重新采完五舰同一源码全集。8cd/4f18旧投影五档只留历史，不能替换这批新图。

其余合法武器组合/全部槽位选择、武器动态朝向/扫掠、其他等级或控件尺寸、自然成长流程、长期性能、Windows/DPI仍未扩测。防御只有逻辑槽与容量身份，不新增可见范围反馈。H1模块最小端口限定结论保持，main与H1组合未安装；整台密度/空位/回执等已审项不重开。停车构图与本批代表装配交原审，未自判全部V0/V2通过。

原目录/分支、缓存与全部tmp保留；不改宿主/main/业务/config/native/战场、不合main、不force，不向用户发中间候选，不用Library/Space。当前无运行任务、无权限阻塞，未实际上下文压缩；只新增本次Git证据与必要规范状态说明。
