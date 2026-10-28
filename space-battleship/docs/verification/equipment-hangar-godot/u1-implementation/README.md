# U1已认可武器与下方品质：内部Godot候选

固定运行源码 **526121392422d459d6b9aa7a1252e36d85b0b4ed**，原目录 `/workspace/space_idle`、原分支 `implement/equipment-hangar-godot`，未合main。按用户已认可U1武器及后续明确授权，只落实装备内部和下方原结构品质；不重做武器方向、整体布局或流程。防御的新整舰选择反馈仍未确认、**未实装**，当前保留侧边真实槽身份以及原防御代理/虚线定位；不能把这部分旧反馈说成完成稿或新设计已获准。原四项保护保持，根审/独审仍须判定本候选，不自判整体视觉/全V0/V2通过。

## 实际改动与范围

运行差异相对旧冻结5b4f7233仅 `src/ui/equipment_panel.gd`：

- 旧大终端/粗机械支承收为左侧180×30文字行，分武器/防御启用组；分组背板184px宽、随真实槽数收缩，单行显示槽号/装备名/付费等级。选中项保留唯一局部强调，未启用/休眠槽不冒充当前启用槽；候选未解锁仍由Equipment决定，不能推断槽不存在。
- 正式舰船、炮PNG、manifest挂点与原350px可见舰体尺度不改。只保留当前选中武器的细前景关联线，括角依已缓存PNG可见区域；合法空武器槽没有可见PNG，不画裸舰体括角/假部件，仍可在索引选择及下方直接安装。
- 下方现装升级、候选浏览/比较、购级/+1/+10/MAX/费用/购买、冷却及独立批量原功能结构不变。缩略图只在初始化一次建立可见区域AtlasTexture、按等比中心显示，正式战场/机库纹理与锚点不裁改，不逐帧扫alpha。候选状态12px，标题/状态分界与底部留白核对；数量/购买/安装按钮统一y812..848基线及高度36，主值27px与金额17px保留，长MAX仍走既有两行主值/多资源账区，不缩金额让位。

未改main/宿主挂载/全局导航、业务/配置/保存、正式船/装备资产及右战场几何。共享宿主仍独立解决顶部与跨层弹层冲突；本文不把原main事实升级为新接入规范。

## 同版真实画面与操作

实际Godot4.7.2、原native正常main/Session；根视口1440×900，左808×900，PNG原像素，未裁切/缩放/拼接。先看[新局Frigate](candidate/01-starter.png)、[Heavy武器1](candidate/32-heavy-weapon-0.png)、[Heavy武器3](candidate/32-heavy-weapon-2.png)、[Heavy武器5](candidate/32-heavy-weapon-4.png)、[合法空槽](candidate/26-heavy-new-empty-slots.png)、[长MAX/多资源](candidate/19-long-max-multi-resource.png)。以上及下列主要场景均已实际用view_image查看；不宣称逐张所有58图均人工审完。

[武器2](candidate/32-heavy-weapon-1.png)/[武器4](candidate/32-heavy-weapon-3.png)与其余五武器图提供真实选择对应；[部分解锁小舰](candidate/25-partial-unlock-frigate.png)、[小舰全候选解锁但六槽休眠](candidate/31-frigate-full-equipment-dormant-slots.png)、[Destroyer左右挂点](candidate/30-destroyer-paired-mounts.png)区分槽启用/候选解锁/休眠。[现装/舰炮候选](candidate/03-cruiser-cannon-comparison.png)、[实际冷却](candidate/09-switch-cooldown.png)、[冷却到期](candidate/10-switch-ready.png)、[真实批量部分成交](candidate/12-batch-partial-result.png)保留原流程。防御逐槽图仅证明原槽选择/下方对象真实对应，不代表新整舰反馈已落地。

[operations.json](candidate/operations.json)保留35条记录、真实GUI InputEvent、所有者报价/回执与前后状态；[candidate.log.txt](candidate.log.txt)为 `EQUIPMENT_CAPTURE_COMPLETE failures=0 records=35`。本批真实执行+1跨材料、+10/MAX购买并用Amount核对扣款/实际count，候选浏览不安装、直接换装及真实游戏时间冷却、批量部分成交/阻挡下层装备点击/关闭重开回执，首防御无卸空入口，Heavy空槽直接装入、五武器三防御逐槽及小舰休眠。新局是真实独立/tmp设置/存档默认状态；后续进度、钱包、等级通过受控restore准备并经真实native接纳，**不冒充自然赚取或解锁流程**，不含个人存档。

第一轮1b40操作采证曾沿旧驱动写入工作台旧证据目录；已将该轮新输出完整保存/tmp及新目录，并按Git逐字节恢复旧45个tracked证据（旧目录diff为空）。发现空槽括角后窄修到52612139，最终整轮重采已明确使用本目录，当前交付不是第一轮挪图。最终驱动/日志和源码哈希绑定本次固定版本。

## 四保护与必要计数

[runtime.json](regression/runtime.json)与[regression.log.txt](regression.log.txt)记录 `REVIEW_RUNTIME_COMPLETE failures=0 moving_signals=97 comparisons=0 reactor_matches=true`；复用既有四保护驱动，只替换输出目录，未造新业务测试设施。

- 未知提交保持未知：[实际Control边界输入图](regression/batch-unknown.png)不显示“等级保持”或已确认成交余额；拒绝/未提交/已接纳缺明细分开，空purchases不推断零成交。这里是呈现边界输入，**不是一次实际native致命故障或财务执行**；正常部分成交另有真实回执。
- 经济位置通知不全量MAX：普通moving与active_moving两个窗口各97次非钱包通知、0次钱包变化；comparison_reads、slot_fact_reads、equipment_option_reads、maximum_reads、refreshes、scene_redraw_requests全部为0。节点/资源及战斗对象等原驱动快照保留，不能由这两个窗口扩大为长期性能通过。
- 反应炉真实比较依赖：[武器免费分配返回](regression/free-weapons-return.png)及[防御免费分配返回](regression/free-defence-return.png)实际操作后UI比较与所有者输出一致、钱包不变，不靠再次选择装备补刷新。
- 右战场等比投影/拾取：逻辑572×960，scale(0.9375,0.9375)、根矩形(855.875,0,536.25,900)，仍位于632×900右区域。真实生成且已拥有Amount的定时掉落仅通过受控restore移到逻辑x32/540，真实根坐标点击移除并核对入账；空白边带点击不拾取。来源范围明确，不把移位准备说成自然生成位置。

GDScript4.7.2检查通过见[check.log.txt](check.log.txt)；仅改GDScript未改native，无新native构建或全游戏/全模块验证。[manifest.json](manifest.json)将最终候选/回归source_hashes逐项对照52612139的Git对象，generated/config.json仅核本地运行捕获hash；每个交付文件及引擎/native库/正式资产记录SHA。源码/数值检查支持操作证据，不代替视觉双审。

## 待审与边界

请原双审判断侧栏材质/文字权重、五武器前景线与PNG括角、正式大小舰主体及下方对齐/图标实际中心；整体视觉未自判通过。防御旧代理/虚线仍可见是明确未完成边界，有限ImageGen反馈研究见[图稿交接](../../../ui-redesign-plan/g1-internal/equipment-image-design/upper-display/README.md)，未确认不实装。共享顶部/导航、跨层弹层输入焦点归整体组，本批不越界修main。Windows/DPI、最小安装尺寸、第五种未取图舰型及长期性能未扩大覆盖；现只确认本次桌面1440×900的所列状态。

最终两工具任务均结束，无仍运行游戏/图像任务；执行者未实际上下文压缩。原证据/本地.import/.uid/缓存均保留，普通提交推送，等待原双审，不合main。
