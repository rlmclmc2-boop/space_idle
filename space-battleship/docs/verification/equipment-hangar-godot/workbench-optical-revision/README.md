# 装备工作区整体排版修正候选：待根唯一审核

## 最新窄修：取消记录及最近结果（2026-10-29）

### 原审P2修正：批量当前等级在Owner刷新后同步

原283b版在_buy_all结束时用旧_facts绘列表，随后正常_refresh虽取得新facts却未更新批量列表，可能滞留或落后一笔。固定源码 `6233dc6ea25bac9a0dfcbc6a8d7b0673e8f24f06`（equipment_panel SHA256 `ae8c4055ed2f227f3b9bd29221dda0aab606fd6a9939a349a8a332b91751eec7`）只迁移一次调用：删_buy_all中的_refresh_batch；在既有_refresh读取Owner slot facts之后，仅批量窗口可见时更新当前等级列表。复用原dirty帧合并，不新增Owner读取、信号、全量控件重建，不恢复结果/历史/提示/tooltip/Toast。

同一正式main/Session/native进程真实GUI连续执行两次批量“每槽+1”：武器1/防御1均Lv1→2→3；每笔释放点击后首个绘制帧列表已与实时Owner facts完全一致，随后帧保持一致，各笔只增加原有1次slot_fact_reads、1次command_finished。原独占及force关闭保持。进程exit0，`BATCH_CURRENT_LEVEL_REFRESH_COMPLETE failures=0`；两张原尺寸整屏已全部实际view_image：[第一笔Lv2](remove-recent-results/batch-level-refresh/01-batch-current-levels.png)、[连续第二笔Lv3](remove-recent-results/batch-level-refresh/02-batch-current-levels.png)。[原操作/计数/首帧文本](remove-recent-results/batch-level-refresh/operations.json)、[驱动](remove-recent-results/batch-level-refresh/capture-driver.gd.txt)、[日志](remove-recent-results/batch-level-refresh/capture.log.txt)、[manifest](remove-recent-results/batch-level-refresh/manifest.json)绑定同版。仅针对该回归，不扩全链或故障矩阵；共享224fa500适配接入边界仍按下文保留。本修正交同一原审，未实际压缩。


本条覆盖下文ce70历史候选中的记录/短反馈方案。按用户最新范围，已删除“记录/最近结果”入口、专属Popup、历史字符串、短时成功回执层、回执tooltip、计时及专属独占连接，不增加替代提示条。批量内成交明细/花费/成交后余额展示也已取消，保留当前槽位等级和必要失败/未知状态。Owner结果数据、last_result及command_finished保持，正常等级/价格/资源不足/冷却状态仍按原规则显示。

固定源码 `283b579543e8d6e5bba8a0f4fd6ef9ecceb6d6f7`，equipment_panel.gd SHA256 `c780015aa91f9c151327d8179bccf99ee693d49cd7e614fb636496834c1ea85e`。只有该运行文件修改；操作行同物购买从数量按钮后连至原右沿，异物安装收回原记录位置，台体高度/标题/数值/候选/费用布局保持。原记录按钮、Popup、吐司无隐藏空节点或占位。下方旧8图/测量/驱动继续保留真实ce70/CEC3版本，不是本次重跑或当前状态。

本次复用environment.md所载Godot4.7.2、原native库、Xorg :99及缓存，独立临时设置/存档，实际正式main/Session/native启动，进程exit0，`REMOVE_RECENT_RESULTS_COMPLETE failures=0`。本次仅定向真实GUI购买一笔accepted（Lv19→20）、切候选、批量及OptionButton独占/force检查，不复跑全套、不以零失败代视觉通过。4张1440×900原尺寸整屏均已实际view_image：

- [新局当前状态/资源不足](remove-recent-results/01-current-state-no-recent-results.png)
- [真实购买后等级/报价更新，无短回执](remove-recent-results/02-accepted-current-state-no-toast.png)
- [异物选择及操作行，无记录占位](remove-recent-results/03-different-candidate-no-record-gap.png)
- [批量当前等级列表](remove-recent-results/04-batch-current-levels.png)

[操作/实例树](remove-recent-results/operations.json)包含原始Owner回执（仅证据，不展示给玩家）；递归检查无ReceiptHistory/ReceiptToast/PopupPanel实例及最近结果文案。实际Batch打开时普通hide拒绝；OptionButton经鼠标输入打开仍独占，force同时关闭二者。[驱动](remove-recent-results/capture-driver.gd.txt)、[原始日志](remove-recent-results/capture.log.txt)、[文件绑定](remove-recent-results/manifest.json)保留。未另采扣费专项证据，不将本次定向运行宣称全保护通过。

接入边界：正常只读fetch并比对组合 `224fa5005e8d0a7c89aa6e7570a78ead71408583`；本地未切换或覆盖宿主。组合版额外的_shared_host_enabled/_shared_hangar_top与_draw顶缝、set_shared_host redraw适配未触碰。整体组应cherry-pick本窄修，保留上述组合适配，不能整文件覆盖成装备分支旧宿主版本。本次4图是原装备分支正式main整屏，不冒充224fa500共享组合实机图；共享组合接入由整体组负责。未改Owner/config/native/main/战场，不合main、不force、不用Library/Space。真实三资源缺生产来源及此前未覆盖边界继续保留；本窄修交原审，不自判通过。

运行源码 `ce70b594b6ffc111eb888d11562312526ebfc675`，原目录 `/workspace/space_idle`、原分支 `implement/equipment-hangar-godot`。用户撤回551a/43a本批视觉放行并明确授权“这些都修正”，本次据此内部落实；本候选尚未由根唯一Astra高通过，不以探针0失败自判视觉。U1武器基本方向、真实业务与四项正确性保护不重开，10游戏秒换装冷却不改；main/宿主/后端/config/native/战场没有修改。

## 已落实的整体排版

| 问题 | 当前实际改变 |
|---|---|
| 左右起始高度/内距不同 | 两边标题同y42，首内容同y70。左图标框x20、主值材质x100；中线x440，右候选x460，末卡至外沿20px。当前图标框及主值面同80px高；右候选保留正式图、名称/状态所需88px。不是仅移动Control后仍留旧内容起点。 |
| 数字/箭头重心偏、留白不平衡 | 用实际Font/TextLine shaped glyph轮廓布局；普通当前/升级数字分别在等宽124px区，箭头放在两侧字形内缘的空隙中点并与数字实绘中心同高。长值保持27px、完整数字，上下两行与下箭头用同一x中心线，按实绘字形空隙重心置箭头，未隐藏箭头。 |
| 名称/Lv散、回执常驻挤标题 | 标题只保留名称与Lv，按字形实宽相邻成组。成功短回执在机库固定(238,150)/340×32轻量层显示3秒后消退，不参与标题或台体布局。操作行“最近结果/记录”按需查看最近8笔原始回执字符串，频繁更新只替换固定反馈层/记录内容。右侧装备选择工位完整保留。 |
| 按钮描边/阴影超轨 | 同物/异物操作行都固定到全局y844；操作轨全局(32,836,744,52)。按钮左右留足原生材质边界，明确处理1px描边、阴影下延3px、按下/焦点态；不是仅Control.rect包住。 |
| 文字最小尺寸撑出旧占位 | 实看预览发现“最近结果”切“记录”时，先设48px再改文字被旧80px最小宽卡住，实际挤安装。当前先改text再设size，异物“记录”真实48px，至安装Control有12px间隔；实际阴影仍分开。 |
| 多资源疏密/不足提示碰轨 | 同物双资源横排，列沟24px，长金额不贴下一资源名；异物双资源紧凑两行。普通/长MAX均是真实Owner双资源。新局“不足”原因使用原费用标题的位置，资源名/金额保留，不再另起一行与操作轨相交。完整原因/报价及实际回执仍可查。 |

同物整台260px（y636..896），异物272px（y624..896）；操作轨与按钮基线保持相同，不独缩一侧，不靠填说明补空。正式未解锁项仍保持原列的纯空位、无卡底/图标/名称/状态/交互；没有改回剪影。原机库固定投影和舰体/正式武器同源变换不改。

## 同版真实整屏与局部

8张整屏均在上述最终源码固定后，同一当前正式main/Session/native/Godot4.7.2进程采集，1440×900、左808×900；8张整屏及8张原像素局部均已实际view_image查看。局部不缩放/重绘/拼贴，坐标与SHA见[manifest.json](manifest.json)。

| 状态 | 原尺寸整屏 | 局部 |
|---|---|---|
| 真实新局、普通数值/未锁纯空位/费用不足 | [01](01-fresh-normal-same.png) | [01局部](crop-01-fresh-normal-same.png) |
| Lv19→20，真实双资源普通同物 | [02](02-double-normal-same.png) | [02局部](crop-02-double-normal-same.png) |
| 真实双资源普通异物 | [03](03-double-normal-different.png) | [03局部](crop-03-double-normal-different.png) |
| Owner长MAX双资源异物 | [04](04-double-long-different.png) | [04局部](crop-04-double-long-different.png) |
| Owner长MAX双资源同物 | [05](05-double-long-same.png) | [05局部](crop-05-double-long-same.png) |
| 三次真实快速购买后的短时反馈、标题无回执 | [06](06-purchase-transient-feedback.png) | [06标题/操作局部](crop-06-purchase-transient-feedback.png) |
| 短反馈消退后按需查看三笔原始回执 | [07](07-on-demand-original-receipt-history.png) | [07记录局部](crop-07-on-demand-original-receipt-history.png) |
| 防御真实槽/双候选、统一起点/数值组 | [08](08-defence-aligned-content.png) | [08局部](crop-08-defence-aligned-content.png) |

作者实际看图确认：左右材质/内容起点一致；普通数值箭头从偏散改为整组，长值下箭头可读；名称/Lv成组，标题右半不再承担回执；记录按钮不挤安装，按钮可见描边/阴影在轨内；不足文字不再与轨边交叉。整体密度、长值垂直箭头及反馈形式仍交根唯一审核，不将这些作者观察写成验收通过。

## 实绘字形与按钮外沿证据

[pixel-measurements.json](pixel-measurements.json)记录真实Label栅格alpha框/重心，而非只比较Control位置。运行侧先按正式字体glyph度量布局；驱动将当前实际Label按原主题/字号复制到透明SubViewport栅格，读实际alpha框作独立检查。

| 数值组 | 实际箭头前/后空隙 |
|---|---:|
| 新局350→420 | 左52 / 右51px |
| 双资源9,300→1.76万，同/异物 | 左37 / 右38px |
| 长MAX上下数值 | 上4 / 下4px |
| 三笔成交后2.56万→3.04万 | 左34 / 右35px |
| 防御1,000→1,200 | 左41 / 右40px |

操作按钮没有PNG边框素材，真实来源是StyleBoxFlat和NotoSansSC字形；已核theme content_margin左右8、上下5，border/expand/shadow/focus等来源。诊断用原按钮的同一主题/样式、原尺寸和原生输入状态在透明SubViewport实际绘制，并阻断复制按钮信号以免下单：两种布局各6按钮×normal/hover/pressed/focus/disabled，共60项。正常/悬停/禁用/焦点的可见alpha可下延Control底3px；按下还可能上延1px。外沿到轨外框最少5px，扣1px轨边后仍有4px内侧净空；左右原生alpha外沿最少9px，扣轨边后8px。

字形bbox中心相对材质alpha框中心各轴最大约1px；量化alpha光学重心最大约1.647px（+10），MAX约1.204px、购买约0.924px。没有为了某条rect居中去缩字或忽略阴影。10张原生购买状态小图均已实际查看，例如[同物正常](button-purchase-same-normal.png)、[同物按下](button-purchase-same-pressed.png)、[同物焦点](button-purchase-same-focus.png)、[异物悬停](button-purchase-alternative-hover.png)、[异物禁用](button-purchase-alternative-disabled.png)。这类透明诊断图补充整屏，不能替代整屏视觉审查。

**旧源测量绑定如实保留：** 60项原生按钮及10张状态图实际采于 `cec3b67f6bfcea73ee6fef38035b57dc62693199`，原始JSON [button-paint-original-cec3.json](button-paint-original-cec3.json)保持原source/hash。最终ce70只把费用不足原因移回费用标题行，没有改按钮。逐函数/hash核对 `_prepare_button_material/_button/_button_tint/_workbench_button/_layout_workbench/_style/_setup_materials` 7函数完全相同，见[preserved-boundaries.json](preserved-boundaries.json)。最终8整屏/8局部/Label实绘数据则全部ce70新采，未把旧源状态图冒充重新运行。

## 真实多资源与明确的三资源缺口

[production-cost-sources.json](production-cost-sources.json)同时核原生产 `config_excel/equipment.xlsx` 与本机真实加载的generated/config.json：12行res_2全部为空；六个可装类型只有res_1=1铁。Owner `_quote_levels`逐res列报价，并在进化跨档追加degenerate_matter。生产单槽及批量聚合最多铁+简并物质两种，当前没有第三种真实费用来源。Owner和Excel原文件hash均固定，未改配置/后端或在UI造费用算法。

本次普通双资源是Lv19→20的1,600铁+10简并物质；长MAX双资源是Owner返回的 `1.145×10^39` 铁+2,760简并物质，当前/升级主值9,300→`1.556×10^43`完整显示。主值/费用均直接使用Owner和Amount.to_display，UI只排列/格式化，不复算成长、MAX或成本。

**未执行项：生产三资源升级报价的普通/长值实图。** 目标是当前真实Owner费用，原因是生产res_2均空、没有可返回第三种费用的实际状态；不是工具拒绝、不是待确认交易，也没有用单资源或合成fixture冒充。其他授权修正及真实双资源已完成供审，三资源证据因缺真实来源保持明确未覆盖，未作通过。通用cost遍历并不构成三资源排布已通过。

## 实际交易、反馈频率与保护边界

[最终驱动](capture-driver.gd.txt)、[操作记录](operations.json)、[最终日志](capture.log.txt)及[解析检查](check.log.txt)：进程exit0，`EQUIPMENT_OPTICAL_LAYOUT_COMPLETE failures=0 records=7`，另有同进程按需记录整屏。3笔真实快速+1均accepted，Lv19→20→21→22；真实purchase_receipt.spent回执依次为1,600铁/10简并物质、1,900铁、2,300铁。本批三笔购买沿用前一长MAX状态的巨额钱包，operations中三笔before/after钱包编码均完全相同。驱动使用同一Amount.sub_nonnegative计算期望值后比对，因此该检查不能证明可观察的精确扣减；原驱动中的“actual frequent spent remains exact”检查名和0失败日志原样保留，但不作为本批精确扣费正常的结论。三笔期间工作台矩形相同、标题只显示对象/Lv，短反馈层原位更新并在3秒后消退，历史中可回看三笔原明细。这里模拟频繁回执到达，不宣称新增或验证自动升级系统。

按需记录是本模块自有Popup，has_exclusive_ui/force hide同时覆盖；实际打开与强制关闭已检查。历史最多8条字符串，不增Owner状态/存档字段。既有command_finished、last_result、故障/成交解释及批量处理保持；_process仅增加UI短反馈计时，不推进10游戏秒冷却或Session时间。

相对43a，[保留依据](preserved-boundaries.json)核18个初始化/候选/命令/详细回执/批量/冷却/投影/定位函数与9个宿主/Session/Owner/战场/拾取/几何/生产配置文件逐字节相同。经济相同预算早返回不改，没有增加Owner查询、全槽读取或舞台重绘；四保护未重开/未全套复测。原U1武器、未锁纯空位、去防御伪贴片和现行冷却规则保持。main/共享导航/H1实际组合未安装；新增记录Popup的全宿主组合门禁仍归整体组。

## 预览问题保全与审查边界

[diagnostics](diagnostics/)保留原预览驱动/记录/日志：其0失败不代表视觉通过，实际看图才识别旧文字80px最小宽压安装和双资源列沟不足；后续CEC3仍有[不足字形跨轨的原图](diagnostics/cec3-before-payment-line.png)，最终ce70已修并只重取同一代表组，没有增加样本批。原始日志不篡改，相关tmp原图全部保留。

旧551a/43a等本批视觉放行已撤回，M2和旧交接已标待修/被本候选替代。本候选仍待根唯一Astra高；没有新开审查者、子任务、工作区，也不向用户发中间候选。未重新采全舰/满装，投影及装配函数虽保持，旧43a至工作台的28.657px不能直接冒充新272px台的实际新图；全部配装/动态朝向、Windows/DPI/长期性能/自然发展/H1整屏/未知故障全链未扩测。

tracked源码与全部证据普通Git推送原分支，不合main、不force、不用Library/Space；缓存、生成配置、个人存档和native工具产物不入Git。当前无运行任务，未实际上下文压缩。唯一实图来源缺口是上述生产三资源，其他修正已形成可审结果。
