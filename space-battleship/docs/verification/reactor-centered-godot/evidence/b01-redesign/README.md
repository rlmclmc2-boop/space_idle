# 反应堆 B01 整模块重设计：当前唯一设计入口

## 2026-10-31 用户复看后的现行返修状态

用户看过本目录交付的三段 1× 实机视频后明确退回：均分仍压实体内边；升级费用资源须与上方“等级”左沿对齐；余额不足要按正式装备的逐资源红字／点击执行才短提示；右上光未贴实际管腔、左右下连接不像实体管、上下接口穿帮，核心通用水波不能表达能量约束／输送。用户进一步要求从“整图＋mask 点特效”改为可组合 core、四设备、独立接口和真双层管路。**下文三段旧片及 Astra 视觉结论只对应退回前版本，现仅保留为历史对照，不再代表现行连接／动态已获用户认可。** 控件与数字返修证据、新模块化舞台实现及性能报告在本页末；未改 Owner、Excel、main 或公共壳，不合 main。

## 用户批准（2026-10-30 UTC+8）
- 12:02：“按这个b1修订后的方向做”。
- 12:03：“面板和上方主体展示效果都要改”。
- 12:04：“这张设计图你自己拿来跟成品对照”。

批准基准：[B01 修订设计图](approved-b01.png)。这是设计方向，不是实机证据。

## 当前目标
整模块按该图接入游戏：上方核心、四模组、舱室、供能连接/工作效果与下方完整控制区一起改，不仅挪底部按钮或给旧资产换皮。核心是主角，四模组有明确功能造型、体量及供能关系。保留现有玩法、Owner契约、模块尺寸与共享宿主边界。

## 信息与操作关系
- 四路分配、百分比、增益集中在一个完整控制区，不再每台设备附独立操作面板。
- 总能量用该区的四色总分配条表达；条内仅显示已配/总量（示例100/100），删掉独立“容量100/已分配100/剩余0”三项栏。未分配部分用条的空余段表达，不能另叠三格读数。
- 保留等级、一枚循环×1/×10/MAX键、独立升级键及与本次数量相符的资源费用、均分。费用不加间隔号或重复倍率。
- 实际参数与颜色身份沿游戏权威数据；图中示例值不是新增数值规则。

## 当前版本与现场
本入口对应 `implement/reactor-centered-godot` 从 `01efbf12e7c2d8a814343fe7503fd692861f4712` 延续的候选；原旧入口：../ship-hub-r9/README.md。本目录保留 `00971d36` 的原四路录像/早期性能与报价图作为历史对照；当前源码新增受控单／双路舱室、1／2／3 路无空槽控制井、八态原板建筑端部及同层左右收边；`936d2e4b` 在不改工作画面的前提下打包 mask 并跳过无效 active 采样，回放基线另由 `68f72e7a` 固定。原整体 Astra `b178ec39` 的十屏结论关闭当前端部**静态视觉**阶段；随后原审已按新片 `b68994bb` 全片每 0.2 秒及关键正常 1× 帧核四路各 25% 持续动态，认定核心／设备／导管可辨、控件／导航稳定、无引导遮挡，限此状态可保。当前 packed 版受控少态连续动态与真实升级至真零过渡已由原 Astra 按两片录像和七张关键帧核为代表状态视觉可保；性能调查有界结论见末节，整组终验仍由整体组负责。下方“整屏统一与合法模块数交接”和末节列出当前源码的八态整屏、交互与性能证据；旧报价图仍只作历史对照；本节末已有当前 packed 版连续录像；整体原 Astra 另按 `07944449` 固定公共组合及本组 `2b057a21` 三张往返整屏核当前装备＋B01 的限定静态跨页组合，未发现公共层视觉阻断，不外推动态或性能。

## 交付与对照
在本目录维护执行进度和固定Git图/视频入口。交同版完整实机画面、正常时间工作视频及必要交互状态；注明受控条件。协调者和既有独立审核按批准图与实际整屏/动态整体对照，包括主体体量、场景一体感、材质、文字、控件与效果，不以问题清单清零或参数通过替代视觉。旧版本局部通过不外推。当前不合main。

## 工具与品质
用户12:07补充：不要以Godot能力限定完成度，若有需求可以使用各种云端工具和技能完成效果。以设计图对应的实机效果为目标，需要时使用可用云端工具/技能生成或处理静态资产、材质与特效，再接入现有运行架构；不是强制使用某一工具，也不以Godot原生随手绘制作为完成标准。

## 本组 B01 实机制作候选

在基线 `c0ecf9b6a0be73eb1127f1a49e1e489fd47cad6a` 之上，整模块上方换成按批准图制作的[无字双态舱室](../../../../../assets/ui/reactor/b01/README.md)：巨型蓝色核心、四种有区别的设备、四根直连实体管路，以及同一张图中的下方金属控制台。Godot `reactor_stage.gd` 的材质按已生效 Owner 负载在闲置／工作光之间切换，并随真实 `game_time` 更新工作相位；零负载用闲置层。旧四角小读面、局部滑杆、脉冲叠层和原底台平铺均从运行场景移除，没有在旧结构上加一层遮盖。静态板不含烘焙控件、文字、数值和滑杆。公共顶栏、导航与战斗仍由原宿主负责。

下方同一金属控制台的总条按 Owner 四路已接纳比例画黄／蓝／橙／紫段，原生文字只显示 `已配 / 总容量`；余量是黑色空段。每行的滑轨、百分比和倍率位于连续玻璃读面。本版把此前独立细线和方头填充改成一套同轮廓的圆角金属玻璃轨槽：`slider-shell.png`、`slider-channel.png`、`slider-glass-fill.png`、`slider-knob.png`。`PowerTrack` 把 Owner 实际比例裁在 148×13 同一内腔中；原生 `HSlider` 操作不变。四行透明图标用 `AtlasTexture` 安放在行名左侧。右区原生均分、`×1 → ×10 → MAX` 循环、独立升级和 Owner 精准报价保持原命令；费用沿共用铀资源图标显示。未改变 Owner 的分配预览／接纳、报价、购买和局部刷新订阅。

运行 shader 的三个源图掩膜由[可复生脚本](../../../../../assets/ui/reactor/b01/generate-effect-mask.py)生成：`effect-mask.png` 固定核心前金属束带，仅让玻璃能量纹运动；把黄光限在真实双炮管管腔；把熔液限在原图 x205–329／y499–588 的炉内开口及流面。新增 `module-mask.png` 按晶体玻璃筒和盾面蓝色穹顶的源坐标及本色像素取样，紫晶折射不进入灰白底座、右金属柱或左传送带。新增 `pipe-mask.png` 按四根实体管路的发光内腔取样，沿各自路径推进的光包与对应 Owner 负载独立绑定。0／4／8 秒全屏及局部抽帧已逐项核核心、武器、盾、炉口、紫晶、四管和控制台，固定机械前景未出现光纹扫动。`reactor_stage.gd` 只在可见、未暂停且 `game_time` 推进时更新相位；真零负载不产生工作光，隐藏页停止渲染。

Godot `4.7.2.stable.official.ed1daf0bf`、native、Xorg `:99`、Mesa llvmpipe、正式 `main.tscn`、1440×900、1×：早期版本[四路带载整屏](active-1440x900.png)、[×10 报价](ten-1440x900.png)、[MAX 报价](max-1440x900.png)、[真零整屏](true-zero-1440x900.png)已按原尺寸目视核对，当前版本四路整屏见下方受控矩阵。右侧等级在顶、费用在中、循环数量与独立升级键并排等高；均分键缩进实体金属框。等级 1 的 ×10 报价为 550 铀，MAX 当时可购 11 级、费用 752 铀，数值取自[同版报价日志](quantity-runtime.txt)，战场收入使 MAX 随余额重算；循环键仅选报价，升级键才交易。对应[报价驱动](quantity-driver.gd.txt)。原批准[B01 主体图](approved-b01.png)未变。

[锁定零态](locked-zero-1440x900.png)、[锁定工作态](locked-active-1440x900.png)及[相位诊断帧](locked-active-phase4-1440x900.png)来自凝聚未开放的公开模型。原生第四图标、行、滑杆、倍率和总条紫段不显示；三模块专用底图移除了整台晶体设备、地面紫晶、完整下右管及接口，环形舱壁、栏杆与金属地面连续，第四静态槽无身份。原数学遮板已删除。[锁定驱动](locked-driver.gd.txt)与[模型日志](locked-runtime.txt)先记录 `enabled=[weapons, defence, smelting]` 的满配 34%／33%／33%，凝聚 shader 负载始终 0；相位诊断向现有视觉时钟输入 4 秒受控增量检查动态贴图，不称为正常墙钟录像。之后驱动通过 Owner 公开 `apply_allocation_plan` 将三路各设为 0，读回总 `allocated=0`、`load=0`、三行 `manual/ratio/load=0`、stage `core_load=0`，待原生绘制完成再取零态图。先前误存的 `locked-zero` 满配画面已撤换；当前文件由驱动的 `confirmed-zero` 帧固定复制，显示 `0 / 100`、三行 `0%` 和暗核。开放四模组底图保持原样。

[交互驱动](interaction-driver.gd.txt)及[实机日志](interaction-runtime.txt)覆盖此次布局后的原生鼠标操作。均分后武器从 25% 拖到 10%，Owner 接纳，总分配变为 85/100；再次拖到超额时返回 `ReactorPlanOverCapacity`，控件回到已接纳的 10%，见[接纳整屏](mouse-accepted-1440x900.png)和[拒绝整屏](mouse-rejected-1440x900.png)。×10 经独立升级键以 550 铀从等级 1 到 11，钱包 1000→450；之后经公开 Economy 入账 1000 铀，MAX 依实时预算报价并以 1336 铀购买 4 级，等级 11→15，钱包 1450→114。两笔成交的提示分别为“已升级 10 级”和“已升级 4 级”，见[×10 成交](ten-purchased-1440x900.png)、[MAX 成交](max-purchased-1440x900.png)。低正负载通过 Owner 公开入口设为 1/5766、`<1%`，见[低正负载](low-1440x900.png)；全部回 0 时，真零整屏显示 `0%` 且工作光关闭。这里的受控入账和开放条件用于覆盖状态，不改变 Owner 或玩法规则；正常战场有实时收益，不能把截图报价当固定初始预算。

费用长价按右区 182×195 的内缘调整：当前源码的[×10 成交](ten-purchased-1440x900.png)与[低正负载](low-1440x900.png)整屏保留完整 `1.1万 铀`；[当前交互日志](interaction-runtime.txt)以原生字体实测此串 60px，详情标签 x688、宽72px，字串右端 x748，距面板右界 x780 仍有32px，未压斜边。资金不足与金额分占两行，普通费用字号仍为16。旧[MAX 报价](max-1440x900.png)可购数量及752铀只作前版动态余额样例。

[正常墙钟录像](live-1440x900-30fps.mp4)为运行窗口 X11 连续采集，10.000 秒、1440×900、30 fps、300 帧，SHA-256 `a76d894ae111040e3dab649980ebf285c85fe19c67a2b8e1d86c3593cbff1b13`。原始采集为 10 秒／299 帧，[原采集日志](ffmpeg.txt)和[恒帧率封装日志](ffmpeg-cfr.txt)记录补 1 帧；无静图插帧或人为改变游戏时间。[录制驱动](capture-driver.gd.txt)与[运行日志](capture-runtime.txt)记录 `VIDEO_READY` 四路各 25%、总负载 1、游戏倍速 1×，35 秒墙钟期间游戏时间推进约 35.67 秒；未执行升级。已目视整屏与录像 2／7 秒帧，核心、四设备、四管及金属台完整，战场同步运行。

性能只在本轮同一台受控 Xorg/Mesa llvmpipe 环境定位：[优化前日志](performance-before-runtime.txt)的同场景 8 秒窗口为不录制 22.90 fps（p50 37.65／p95 51.22 ms）、录制 20.21 fps（p50 46.05／p95 69.59 ms）；[优化后日志](performance-after-runtime.txt)为不录制 26.87 fps（p50 32.71／p95 41.59 ms）、录制 24.44 fps（p50 39.01／p95 54.16 ms），隐藏反应堆页为 34.56 fps、工作相位更新 0。[采样驱动](performance-driver.gd.txt)保持同一分辨率、1×、四路各 25%；仅在 shader 的静态控制台 `uv.y >= 0.58` 区域跳过无效工作场计算，上方动态效果未降质、未限帧或改逻辑。这是软件渲染环境中的定位证据，不代表目标硬件帧率或性能门槛已通过。先前因引导使时间不推进、录像未开始的采样已剔除，不纳入本组数字。

本候选已做受影响实机操作、最终源码静态整屏与锁定态相位诊断核验。[Godot 4.7.2 `--check-only` 日志](check-only.txt)无脚本／shader 错误；`git diff --check` 通过。候选交协调者与独立审核，当前不合 main。

## 整屏统一与合法模块数交接（待整体接口固定）

用户已退回装备与反应堆的跨页语言及左外缘、右侧导航交接；本组的局部图和性能采样不代表该整屏问题通过。当前反应堆候选从 `b57b7089073a0a67d0a8adba419733426498b4eb` 续作少模块台面；旧 `587cf2f9f99d1cf06d8b3fb8e62c1aef6dd72fa2` 只用于历史接缝定位；2026-10-30 核到的整体远端 `design/clear-zone-host@61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1` 的运行树接了同一 `eea1a7e6` B01 源码。整体分支后续跨页字体 R3 是静态设计预览，尚非固定运行材质或左右边界协议。该分支的完整[反应堆](https://github.com/rlmclmc2-boop/space_idle/blob/61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/eea-combo-reactor-1440x900.png)和[装备](https://github.com/rlmclmc2-boop/space_idle/blob/61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/eea-combo-equipment-1440x900.png)是已存在的同壳运行图，供定位退回问题；不是新版统一已通过证据。本分支的整屏图仍在旧 `main.gd` 宿主下取得，不能冒充整体组合。

| 可见模块数 | Campaign／Owner 合法来源 | 本组现有整屏与结论 |
|---|---|---|
| 1 | 用户描述初开放仅炼铁，但现行 Excel 未列单独门槛、Owner 实际同时开放前三路；自然关卡尚无该状态。 | **受控隔离 Owner 输入**仅 `smelting`，专用底板为连续控制井、原生单行居中且无三处空槽：[真零](controlled-one-zero-1440x900.png)、[均分 100%](controlled-one-active-1440x900.png)及[真实鼠标拖到 47%](controlled-one-manual-1440x900.png)，Owner 接纳 47/100；武器、盾甲、凝聚实体／管路／工作光及控件行、总条段均无。此图不冒称自然进度。 |
| 2 | 当前 Excel 未声明中间两路关卡；不推断自然可达。 | **受控隔离 Owner 输入**`weapons,smelting`，专用连续控制井承载居中的两行、无另外两处空槽：[真零](controlled-two-zero-1440x900.png)、[均分 50/50](controlled-two-active-1440x900.png)及[真实鼠标把武器拖到 26%](controlled-two-manual-1440x900.png)，炼铁仍 50%，Owner 接纳 76/100；盾甲、凝聚实体／管路／工作光及控件行、总条段均无。此组合只是覆盖 2 路布局与分配，不新增玩法。 |
| 3 | 当前 `Reactor.refresh_availability` 在反应堆可用后无条件启用武器、盾甲、炼铁，只有凝聚查询 Campaign；这只描述当前实现。用户描述下一关武器、盾甲加入，源表尚未声明这一步。 | 原正式 Owner/Campaign [真零](locked-zero-1440x900.png)与[三路均分](locked-active-1440x900.png)为 34/33/33%、100/100；专用连续控制井承载居中的三行，不留第四空槽；最新边缘版另有[受控真零](controlled-three-zero-1440x900.png)和[均分](controlled-three-active-1440x900.png)。右下未开放设备、管路、工作光与第四控制行/紫色段均无。 |
| 4 | 当前 Owner 在凝聚可用时加入第四路；Excel 凝聚门槛为 cleared 关卡 15。 | 原正式 Owner/Campaign [四路真零](true-zero-1440x900.png)与[四路均分](active-1440x900.png)各 25%、100/100；最新边缘版另有[受控真零](controlled-four-zero-1440x900.png)和[均分](controlled-four-active-1440x900.png)。[×10 报价](ten-1440x900.png)、[MAX 报价](max-1440x900.png)及[成交](ten-purchased-1440x900.png)记录升级区与按钮行为。 |

**纠正 `f33ed6c` 的错误推论：**运行配置 `generated/config.json`（本工作区 SHA-256 `308b8f8089750db99e0190526f2f1fde91ee2950c5229567d295860b04d077de`）和 `src/systems/reactor.gd::refresh_availability` 只能证明现行实现把前三路同时开放，不能证明它符合设计。用户明确初开仅炼铁、下一关再开武器与盾甲；1 路为用户要求覆盖的设计状态，2 路不能只凭当前 Owner 策略排除。现有受控 Campaign 恢复图只说明当前运行态，不是自然关卡顺序实测。三路／四路均分和 ×10／MAX 的 Owner 状态、原生控件及鼠标操作由本目录日志支持；最终整体组合中的均分视觉、控制台主次与跨页统一仍待核。

2026-10-30 源链复核：运行配置源 `config_excel/unlock.xlsx` SHA-256 `ee216e7524e918279a967220c1a205cfd433fe2c9c389c2a7f2a2a35525b2ed7`，`unlock` sheet 第 15 行是 `feature/reactor, level=1, mode=cleared`，第 31 行是 `reactor_module/condensation, level=15, mode=cleared`；全表没有 `reactor_module/weapons`、`defence` 或 `smelting` 行，也没有别名行。`foundation/import_excel.py` 调用 `config_tools/compile.py::compile_config`，现行 `generated/config.json` 同样只有上述反应堆开放行，故**不是导出漏行，而是 Excel 源没有声明前两路门槛**。`Campaign.available(kind,target)` 只按 `type/target` 精确匹配、满足 `cleared_stages` 或 grant 后返回 true，缺行会返回 false；`Reactor.refresh_availability` 第 64 行以 `module != "condensation" or unlocked(...)` 把武器、盾甲、炼铁无条件加进可用集合。Session 创建时 `game_session.gd:112`、恢复后 `:230`、进度发布 `:1359` 都调用该刷新；`Reactor.presentation_model` 带 `_enabled`，`reactor_scene.gd::_refresh` 仅显示 enabled 行并据此更新 stage。因此现行实现是 cleared 关卡 1 后直接三路，与用户描述的“初开炼铁、下一关再加武器盾甲”不同；由于源表无该条件，按用户限制**暂不改正式 Excel、导出配置或 Owner 解锁规则**，也不把“下一关”擅定为具体关卡数。受控验证从同一参数复制仅换 `reactorModules` 输入，在隔离 Reactor Owner 上调用公开 `refresh`、`apply_allocation_plan`，并通过原生 UI 均分键调用 Owner `distribute`；1／2 还由真实 `InputEventMouseButton/Motion` 拖动原生滑杆，从隔离 Owner `presentation_model()` 读回接纳值，非直接给图改数。原 Session 及其正式 Owner 保持原样。[受控驱动](controlled-states-driver.gd.txt)与[四态日志](controlled-states-runtime.txt)记录每态 Owner `modules/load/ratio`、UI 行集合、stage 负载和按键状态。隔离 `publish` 只接受该 Owner 候选，不证明整场 Session/native 因子发布或自然解锁流程。1／2 为受控显示与分配证据，3／4 另有上述现行 Campaign/Owner 整屏证据。

**性能仍待用户目标硬件与最终共享组合验收。** 此分支继续保留 shader 静态控制台 `uv.y >= 0.58` 跳过无效工作场计算；新增在对应纹理 mask 为零或 Owner 负载为零时跳过该管路／机器昂贵动态函数，仍逐帧推进相位，保留完整四路材质、工作光与业务逻辑。此版又在同一舞台 shader 的最终颜色将左右 24px 平滑收至公共深蓝 `#0d2533`，不加模块外装饰层，中央主体不受影响。此前 `587cf2f9` 单活实例 8 秒[基线日志](performance-current-runtime.txt)为不录制 25.31 fps、录制 21.08 fps、隐藏反应堆切装备 32.89 fps。无边缘收束的优化中间版[日志](performance-final-runtime.txt)为 33.72／28.27／34.65 fps；**当前边缘版**同 Xorg/Mesa llvmpipe、1440×900、1×、四路各 25%、速度 1 的 8 秒[日志](performance-edge-runtime.txt)为不录制 33.48 fps（p50 29.11／p95 35.48 ms）、录制 27.88 fps（p50 34.88／p95 45.88 ms）、隐藏切装备 34.67 fps（p50 27.41／p95 35.49 ms）；[ffmpeg 日志](performance-edge-ffmpeg.txt)与[驱动](performance-final-driver.gd.txt)固定录制窗口。当前同环境可见／隐藏差约 1.19 fps，已非先前约 7.58 fps，但不同页面画面也变了，不能视作反应堆独占成本；录屏与游戏争用软件渲染 CPU。旧 00971 的 22.90→26.87／20.21→24.44 fps 仅是上一版短窗，不与本版混算。

[诊断日志](performance-diagnostic-runtime.txt)在优化前同实例测得全效果 25.65／恢复后 28.03 fps、只暂停相位写入 45.66 fps、等尺寸低成本材质但保相位写入 39.71 fps；后两项仅诊断，已撤销。可见窗内 `presentation_counts` 的 model／quote／preview／commands 均为 0、节点稳定 53、stage 绘制与静态场更新为 0、相位几乎每帧推进；所以**没有观察到隐藏页反复建控件或可见页高频报价／布局重建**，主要差异在动态材质像素工作与使其更新的相位写入，CPU/GPU 精确占比不能由 llvmpipe 分离。[同实例 ABAB 日志](performance-abab-runtime.txt)及[驱动](performance-abab-driver.gd.txt)在相同四路状态各 6 秒得原材质 27.80／27.94 fps、优化材质 33.44／33.92 fps。边缘收束加入前的短时固定相位[原材质](performance-original-phase.png)和[优化材质](performance-optimized-phase.png)，反应堆完整 `x=0…807,y=0…899` RGB 逐像素差为 0，证明工作效果计算优化自身无画面损失；当前版本刻意只改左右 24px 的最终收边，不能再声称与旧整图逐像素一致。右侧战场自主动画有差，未拿全屏差冒充 B01 差。目标硬件、最终跨页共享宿主、明确帧率门槛尚未提供／验证，故**不宣称最终性能通过**；目前仅能说此软件渲染环境内原约 10 fps 量级的可见／隐藏差已缩至约 1 fps。

| 绘制/布局边界 | 当前实际归属与接缝 |
|---|---|
| B01 内区 | `reactor_scene.gd` 根为 `808×900`、裁剪开启；`SubViewportContainer` 位于 `(0,65)`、尺寸 `808×835`。`reactor_stage.gd` 将整张不透明的 `1187×1326` 舱室加金属台底图绘到此内区；此版 `live-material.gdshader` 在原场景层内把左右约 24px 连同下台面端收向宿主深蓝，x0/x808 不再直接呈亮色断面。内部控件、均分、等级、费用和工作效果归 B01。 |
| 整体宿主 | 最新整体运行源 `zone_shell.gd` 绘顶轨 `y=0…65`（装备 `0…85`）、中间导航暗带 `x=808…855.875` 与 `x=808/854` 边线；战场投影 `x=855.875…1392.125`，最右保留 `47.875px`。`main.gd::_draw` 底色在不透明模块图后不可见。导航、资源、页面显隐、战场投影及公共边线归整体。 |
| 当前断点 | 本组源板 `26fe98d5` 的八态建筑端部已临时叠到整体固定运行树 `051cbd0d` 真跑 `main.tscn`，1／2／3／4 零载／均分整屏和 1／2 鼠标状态见下节。原舞台 `x0…807,y65…899`、公共导航 `x808…855` 未改，图上端部和控件无覆盖冲突。原整体 Astra 已按固定 b178ec39 真组合十屏给当前端部静态视觉阶段可交结论；装备新运行资产与动态/性能同版仍待。此叠图是可回放候选，不等于整组已合并或跨页最终验收。 |

| 用户退回项 | 本分支当前证据与未完范围 |
|---|---|
| 均分、等级升级区 | 受控 1／2／3／4 Owner 分配和按钮可见、四路报价／成交及 1× 整屏已有证据；共享 051c 宿主下原生 1／2／3／4 行位、等级费用和 1／2 鼠标净空已实核；四路 ×10/MAX 成交仍见前次 656 同源代码证据，最终视觉取舍待整体原审。 |
| 1／2／3／4 模块 | 受控 1／2 的整实体、管、光、控件行、总段隐显和分配已覆盖；1／2／3 底台重制为无空槽的连续金属读面，原生行按 enabled 数重排，四路原布局不变；现行自然实现为 3／4，用户描述的单路自然关卡源表无门槛，遵其要求暂不改正式解锁。其他任意两模块组合没有单独绘制资产，当前受控双路专指武器＋炼铁。 |
| 性能 | 当前边缘版全效果同环境短窗从 25.31／21.08 提至 33.48／27.88 fps（无录／录屏），可见／隐藏环境差缩至约 1.19 fps；051c＋八态端图组合又测可见 27.33／隐藏 30.40 fps（各 8 秒，未录），仍非目标硬件验收，不以诊断冻结态作产品。 |
| 跨页风格及左右边界 | 原舞台 shader 24px 深蓝收边外，八态源图已加入真实建筑端部并在 051c 公共壳逐态取整屏；B01 八态端部静态真组合已获限定审结论；装备新版仍是设计比较，跨页异材质待运行同版审。 |

以上是边界与证据交接，不是整体统一完成。B01／公共壳同版候选已有整屏与短性能证据；后续 `2b057a21` 已有正式装备面板窄接当前公共宿主的运行整屏，整体原 Astra 已按 `07944449`＋本组三张往返图给出限定静态跨页组合可保结论；动态与整组终验仍待核，当前不合 main。

### 共享宿主接入的现有运行接口

本组仅拥有 `reactor_scene.gd` 根 `808×900`（`clip_contents=true`）、其 `(0,65)` 的 `808×835` `SubViewportContainer`、`reactor_stage.gd` 和 `assets/ui/reactor/b01`；按现 `live-material.gdshader`，原舞台左／右约 24px 在最终颜色内收向 `#0d2533`，包括下金属台端，非宿主外叠层。该收边目前仍是候选，整体 `b17db8d2fef26009515df75b5759b6b1ac7ca3fb` 的端盖研究图不是运行资产；其文稿也明确要按同几何核所有 idle/active/少态图与 mask。公共 `zone_shell.gd` 当前顶轨在反应堆页高 65、左工作区外的导航带 x808…855.875，x808/854 边线、资源和战场投影归整体组；本组不重写公共导航、路由或主场景。

当前 `main.gd::_setup_reactor_scene` 在现有 CanvasLayer 中以 `session.reactor_system`、`session.reactor_inputs`、`session.economy.payment`、`session.publish_reactor`、`session.economy.can_pay` 构建场景；`bind_presentation` 只读 `presentation_model()` 并传 `game_time/paused/running`，`bind_purchase_quote` 只读固定数量或 MAX 的 Owner 报价。`presentation_changed` 使模型标脏；`budget_changed(resource_ids)` 仅在与当前 `cost_resource_ids` 相交时标脏报价，MAX 零可购的空成本不订阅虚假资源。原 UI 均分／滑杆经 Owner 公开分配命令接纳，循环数量只切报价，独立升级键才交易。B01 页不可见时 `_process` 关闭、SubViewport 为 `UPDATE_DISABLED` 且 stage 时钟重置；可见且未暂停、真实游戏时间推进、有正总负载时才更新相位并请求一次绘制。`main.gd::_refresh_left_module` 依 Campaign feature 可用和当前路由设置 scene.visible；整体公共宿主应继续拥有这层可见路由，不把隐藏页持续更新或新建 B01 控件。

2026-10-30 UTC 更新：整体远端 `design/clear-zone-host@d0fb49c5` 已精确接入本组 `e8ec7c44` 的六张连续控制井图与 `reactor_scene.gd` 原生行居中，文件哈希与本组相同；`main.tscn` 的同版 4 路均分／MAX 报价、受控 1／2／3 路零态与均分、1／2 真实拖动整屏均固定在整体组的 `runtime-clear-zone/evidence/e8-*`。本组已按原尺寸看四路与单路组合图：控制井、均分、等级、费用及公共导航可读；`x=0/808` 的舱景和下台端仍呈裁断，不能据此称跨页材质衔接通过。该组合的装备返回图已改用固定旧装备源作可复现路由对照，仍不是装备新稿实装。整体组后续 `65692390` 提供四路数左右端部 R1 **设计合成**：仅换屏幕两侧约 60px、`y65–525` 上景，下台、中心与战场保持原像素；它不是八张原板的运行贴图，也没有修下台端。下一步需在本组 1／2／3／4 的八张同坐标 idle/active 原板内完成真实建筑端部，再同版核公共 `y65` 顶轨、`x808–855` 导航和各态 mask；原组合驱动断言的四路均分、MAX 报价与 1／2 拖动，已由下节本组短核补上升级成交及性能。最终组合仍需装备新版运行资产与原整体审的具体退点，不合 main。

### 共享 e8 真交互与性能短核（固定运行树 `65692390`）

本组在**同一工作区临时检出** `design/clear-zone-host@65692390b468314a2f769afc76c8b74c44cf1666`，只注入现成的 Godot 4.7.2 native 扩展清单；以 `main.tscn`、Xorg `:99`、Mesa llvmpipe、OpenGL3、1440×900、1× 跑[共享交互驱动](shared-e8-interaction-driver.gd.txt)与[日志](shared-e8-interaction-runtime.txt)。驱动仅把本组原交互脚本的路由改为公共导航、开放夹具保留为 Campaign grant、清掉提示后取帧；源码和配置未改。四路原生鼠标均分后，武器由 25% 拖到 10%，Owner 接纳 `85/100`；超额再拖被 `ReactorPlanOverCapacity` 拒绝且滑杆回到已接纳 10%。[接纳](shared-e8-mouse-accepted-1440x900.png)、[拒绝](shared-e8-mouse-rejected-1440x900.png)是该运行树整屏。

真实鼠标循环键选 ×10，独立升级键使等级 `1→11`、铀 `1000→450`，准确扣 `550`、提示“已升级 10 级”，见[×10 成交](shared-e8-ten-purchased-1440x900.png)；之后通过公开 Economy 临时入账 `1000` 铀供 MAX 状态，真实鼠标选 MAX 并升级 `11→15`，铀 `1450→114`，准确扣 `1336`、提示“已升级 4 级”，见[MAX 成交](shared-e8-max-purchased-1440x900.png)。两笔均以 Owner 级数、钱包 Amount 和 UI 回执断言，入账只属受控证据。等级 11 的 Owner 公开分配 `1/5766` 显示 `<1%` 且负载为正，见[低正载](shared-e8-low-1440x900.png)；设真零后显示 `0%`、stage `core_load=0`，见[真零](shared-e8-true-zero-1440x900.png)。长价 `1.1万 铀` 以原生字体实测宽 60px、从 x688 到 x748，距面板右界 x780 尚有 32px。购买截图的顶部资源、公共导航和右侧战场同版可见；本组只据这些状态判定操作与局部净空，不外推完整跨页品质验收。

[共享性能驱动](shared-e8-performance-driver.gd.txt)、[单实例日志](shared-e8-performance-runtime.txt)、[录制日志](shared-e8-performance-ffmpeg.txt)与[9 秒／225 帧实录](shared-e8-performance-1440x900.mp4)固定同一运行树四路各 25%、游戏速度 1×。8 秒窗口：可见不录 `31.24 fps`（p50 `30.35`／p95 `37.07 ms`）、录制 `28.52 fps`（p50 `35.09`／p95 `42.53 ms`）、隐藏反应堆切装备 `34.60 fps`（p50 `27.83`／p95 `33.93 ms`）；可见游戏时间分别推进 `7.97`／`6.97` 秒，隐藏推进 `8.00` 秒，stage 活跃相位帧分别 `249`／`194`／`0`。视频为 X11 连续采集，1440×900、25 fps、9 秒，SHA-256 `b0940d234dd5fb8378d2c6d24e59f59cc177f9aa2d3c6b9afbcfce3fece12a8f`。首次短窗另有本组前一交互 Godot 实例残留争用 CPU，结果约 15–16 fps，已仅终止该本组实例并舍弃，再在无其他本组运行实例条件下取上述单实例数据；这与早先本组旧宿主 33.48／27.88／34.67 fps 不是严格同场 A/B，不能把数字差归因于 B01 或公共壳。软件渲染采样不代表目标硬件门槛通过。临时检出结束后已回到反应堆分支，tracked 文件无共享源修改；接下来仍需八态原图端部、最新装备运行组合及原整体审。

### 八态源板建筑端部候选

整体 `design/clear-zone-host@051cbd0dc201fb53578d9c074460b8969a207ef8` 的 R2 源图合同 `space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/b01-endcap-r2-source-contract.json`仅固定设计方向，不是运行资产。本组在原 `1187×1326` 的单／双／三／四路 idle/active 八张源板内加入两侧舱室立柱、栈道回折、地面扶梁与控制台侧颊；参考的四张 [ImageGen 研究源图](endcap-source/)只取建筑边缘。编辑脚本 [compose-endcaps.py](compose-endcaps.py)从 `e8ec7c44` 原板重建，中心 `x145…1041` 全高逐像素不变；active 的边缘工作亮度沿用同态原板相对 idle 的差值，现有 `effect/module/pipe` 三 mask 未动。低处收窄到原控制台侧颊以保留 1／2／3 连续深蓝控制井和四路原行分隔；`two-idle` 原板少一行，重建时只延续末行至共同 `1326` 高，不改坐标。四态零载／工作及行位先在旧宿主真运行 1440×900 核对，再按下述固定共享运行树复核八态、`y65` 顶轨与 `x808…855` 公共导航接缝。

已在**同一工作区临时检出**整体运行树 `051cbd0dc201fb53578d9c074460b8969a207ef8`，只从本组 `26fe98d5222912f5d99c7029353bcb79ba7d4ae0` 覆写上述八张 PNG，借入 4.7.2 native 清单，运行后恢复整体树并返回本分支；公共壳、`main.tscn`、Owner、mask 均未修改。固定 `main.tscn`、Xorg `:99`、Mesa llvmpipe、OpenGL3、1440×900、1× 的 [八态驱动](shared-r2-eight-state-driver.gd.txt)与[运行日志](shared-r2-eight-state-runtime.txt)记录受控 1／2／3／4 Owner 零载和均分；1／2 为用户指定受控状态，正式 Excel 门槛未改。矩阵真运行整屏如下：

| Owner 可用路数 | 真零 | 均分工作 | 鼠标改分配 |
|---|---|---|---|
| 1：炼铁 | [整屏](shared-r2-1-zero-1440x900.png) | [100%](shared-r2-1-active-1440x900.png) | [47%](shared-r2-1-mouse-1440x900.png) |
| 2：武器＋炼铁 | [整屏](shared-r2-2-zero-1440x900.png) | [50%／50%](shared-r2-2-active-1440x900.png) | [武器 26%](shared-r2-2-mouse-1440x900.png) |
| 3：武器＋盾甲＋炼铁 | [整屏](shared-r2-3-zero-1440x900.png) | [34%／33%／33%](shared-r2-3-active-1440x900.png) | — |
| 4：全模块 | [整屏](shared-r2-4-zero-1440x900.png) | [四路各 25%](shared-r2-4-active-1440x900.png) | — |

逐张看真整屏：侧柱到上轨下沿、左右栈道和地面进入控制台侧颊；控制井没有重新出现空槽，原生行、等级、费用、均分按钮与导航边线均可辨；右边机器在舞台内止于 `x807`，公共导航从 `x808` 起，未发现遮罩盖住点击区。结构端部与装备新运行版的最终美术衔接仍需整体原审，以上只证明这组固定候选在公共壳内可运行、可看、可交互。共享购级 ×10/MAX、低正载／真零证据见上节同一代码基线 `65692390`；新端图没有改其交互代码。

[当前组合性能驱动](shared-r2-performance-driver.gd.txt)与[日志](shared-r2-performance-runtime.txt)只测未录可见和切装备隐藏两个 8 秒窗口，四路各 25%、1×、单活 Godot：可见 `27.33 fps`（p50 `32.33`／p95 `57.16 ms`，游戏时间推进 `7.95 s`），隐藏 `30.40 fps`（p50 `29.21`／p95 `46.58 ms`，游戏时间推进 `7.28 s`），相位帧分别 `218`／`0`。这是不同时间的 051c＋端图单次短采样，不与 656 的 `31.24/34.60` 作严格 A/B 或将差异归因于贴图；软件渲染结果不代表目标硬件帧率通过。共享宿主和装备未来运行材质若变，仍须整体同版性能验收。

#### 本组复看与原审具体裁定点

2026-10-30 再按上述十张真实整屏逐一看零载、工作、1／2 鼠标：八态控制井均无烘焙空槽；单／双／三／四行居中、费用不足橙字、升级与均分没有被侧柱遮挡。上部侧柱从顶轨下沿连到回廊，下部沿原控制台侧颊落到屏底；但多路工作态左侧武器前端、右侧盾舱外缘仍紧贴 `x0/x807`，尤其[四路工作](shared-r2-4-active-1440x900.png)可见右侧蓝色盾球贴边。此候选比整体最新 R3 精确设计研究中的端柱更窄；虽然同版运行、边线和点击净空已核，**端部视觉是否足够遮断截口须原整体美术审明确裁定**，不能仅以这组断言称已解决用户退回的全屏接缝。若退回，需指定这两个端口的可见宽度／遮挡要求，再由本组在八张原板同几何修，不以公共导航或整图叠框代替。

整体远端 `design/clear-zone-host@23819624d2277b4b52f1ac1dd858912780a4cbcc` 自 `051cbd0d` 以来只新增 `runtime-clear-zone` 的 R3 B01 精确研究与 e154 装备早／中／晚端部**设计**比较，`src`／运行 UI 资产无新改动；其文稿明确这些不是装备运行实现。故当前可复现真实公共组合仍为 `051cbd0d` 加本组八 PNG；还缺装备原组固定的新运行材质 SHA 与其早2／中5／晚8实机图供同版跨页判断。051c 原短窗可见／隐藏差 `3.07 fps` 与前次 656 的 `3.36 fps` 量级相近；这不证明端图性能零成本或用户目标通过，后续同版 shader 优化见下节。

原整体 Astra 已按其固定 `b178ec39` 真组合十屏作**静态视觉**审：侧墙至台颊、公共导航与少态原生控件无明显遮断，可作为当前静态视觉阶段的候选，不再把“八态端部尚缺静态审”列作未完。该结论仅覆盖所审固定整屏；其后四路 25% 连续动态已有下文 b689 限定复审；此处记录当时的未完边界；后文已固定少态动态代表状态视觉原审、当前公共树正式装备同版及有界性能结论。自然 1／2 门槛按用户指示暂不改。上段关于武器／盾球贴近边缘是交审观察，不表示静态阶段被退回；若后续审提出具体美术退点，本组按原舞台修源图。

### 同版 shader 剩余成本：packed mask 与按需底图采样

在整体 `051cbd0d`＋本组八板的同一运行树上，以 Godot 4.7.2、Xorg `:99`、Mesa llvmpipe、OpenGL3、1440×900、四路各 25%、1× 做两个不同候选的 6 秒配对：正序 ABAB 是最终 packed mask＋按需 active 采样组合；反序 BABA 是仅 packed mask 的中间候选，不能合并为同一产品的正反序保证。最终保留的变更把原 `pipe/effect/module` 三纹理的**原始像素通道**按 [pack-runtime-masks.py](pack-runtime-masks.py) 装入两张 RGBA mask：`pipe_effect` 为管 R/G/B＋核心效果 R，`module_effect` 为设备 R/G＋枪口效果 G＋熔流效果 B；原三张 mask 不删不改。新 PNG 的 `.import` 明确 `process/fix_alpha_border=false`，否则 Godot 会在 alpha 为零处改写 RGB，已实测同相位局部差最高 90 级，不能拿默认导入物替代。shader 仍逐帧推进原相位、四路导管与机器工作效果；在 `blend_power==0` 的上景像素跳过多余的 active 底图采样，不降低刷新、亮度或 Owner 工作逻辑。

[ABAB 驱动](performance-packed-active-abab-driver.gd.txt)／[日志](performance-packed-active-abab-runtime.txt)的原版 `31.29/31.61 fps`、组合候选 `32.33/32.23 fps`；[反序 BABA 驱动](performance-packed-baba-driver.gd.txt)／[日志](performance-packed-baba-runtime.txt)的原版 `31.87/31.54 fps`、仅 packed mask [固定 shader](performance-packed-only.gdshader.txt)候选 `32.67/32.61 fps`。每个窗口游戏时间和 shader 相位约推进 6 秒，stage 静态绘制／field 更新为 0，UI 节点 53 不变；当前产品只对应正序 ABAB 的 `+1.04/+0.62 fps`；反序 BABA 的 `+0.80/+1.07 fps` 仅说明 packed-only 中间候选，不为当前产品背书。不同运行间数字不作严格 A/B，目标硬件仍未过。[固定相位旧版](performance-packed-baseline-same-phase.png)和[组合候选](performance-packed-candidate-same-phase.png)在完整 B01 舞台 `x0…807,y65…899` 的 RGB `674,680` 像素逐像素相同；基线 shader [源码](performance-packed-baseline.gdshader.txt)由 e8 当前运行版固定。成品只绑定两张 packed mask 的 [受控八态日志](performance-packed-eight-state-runtime.txt)亦核 1／2／3／4 零载／均分及 1／2 鼠标接受，无脚本错误。该像素比较针对四路固定相位，不自动替代所有交互场景或最终新装备同版验收。

诊断淘汰：椭圆外接框早退同相位零差但 ABAB 无稳定收益；8 位预计算静态几何虽约快 1 fps，却在椭圆边缘最高差 61 级；浮点几何需约 11 MB 新纹理，仅约 `0.5–1 fps`，半精度约 5.2 MB 但收益不稳，故不纳入产品。上述实验文件留本组临时路径而未引入额外运行资产；当前产品变更仅两张打包 mask、对应导入设置、同层 shader 和 stage 参数绑定。

### 当前 packed 版共享动态桥接

在**同一工作区临时检出**整体运行 `051cbd0dc201fb53578d9c074460b8969a207ef8`，仅叠本组 `6c1367e0719ebd5a537741b73c62b2d6116286cf` 的八原板、`live-material.gdshader`、`reactor_stage.gd`、两张 packed mask 及其 `.import`；运行后逐文件核与本组 Git 对象同 blob、恢复原分支，公共 `main.tscn`／导航／战场／Owner 未改。[当前共享交互驱动](shared-packed-interaction-driver.gd.txt)与[日志](shared-packed-interaction-runtime.txt)复用前次真实鼠标及 Owner 断言，Godot 4.7.2/Xorg `:99`/Mesa/OpenGL3/1440×900/1× 无脚本错误：武器由均分拖至 10% 得 Owner 接纳 `85/100`，[接纳整屏](shared-packed-mouse-accepted-1440x900.png)；超容量拖动被 `ReactorPlanOverCapacity` 拒绝并回到已接纳的 10%，[拒绝整屏](shared-packed-mouse-rejected-1440x900.png)。真实鼠标选 ×10 后独立升级 `1→11`，铀 `1000→450`、扣 `550`、提示“已升级 10 级”，见[×10 整屏](shared-packed-ten-purchased-1440x900.png)；随后受控入账 1000 铀供 MAX，真实鼠标选 MAX 后 `11→15`，铀 `1450→114`、扣 `1336`、提示“已升级 4 级”，见[MAX 整屏](shared-packed-max-purchased-1440x900.png)。[低正载](shared-packed-low-1440x900.png)显示 `<1%` 而 Owner 负载为正，[真零](shared-packed-true-zero-1440x900.png)显示 `0%` 且核心动态关闭。此证据补上新 shader 源码下现有四路鼠标／购级链；1／2 仍是上一节同产品源码下的受控 Owner 鼠标，静态审结论不因此自动扩为整体动态／新装备同版通过。

### 当前 packed 版连续工作画面

[10 秒完整录像](shared-packed-continuous-1440x900-25fps.mp4)是同一工作区固定共享宿主 `051cbd0dc201fb53578d9c074460b8969a207ef8` 叠加 [14 文件闭包](integration-closure.json)中的 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 当前 B01 产品源码与八张原板、两张 packed mask 的实际窗口采集；录前已逐文件核 SHA-256 与闭包一致。两张 `.png.import` 均为 `process/fix_alpha_border=false`，否则零 alpha 处 RGB 会变化。公共 `main.tscn`／Owner／战场未改，入口 `res://src/main.tscn`。临时 [驱动](shared-packed-continuous-driver.gd.txt)只受控授予四模块可用状态、点原生均分、清除既有引导并等待录制；[Godot 日志](shared-packed-continuous-runtime.txt)确认 1440×900、1×、负载 1.0、四路各 25%、从 `VIDEO_READY` 到录制结束（含 ffmpeg 启动前的等待）工作相位 `2.45→20.35`、游戏时间 `2.63→20.57` 秒，末尾引导为空，无脚本错误；这段区间长于视频，不能用其计算视频段帧率。受控四路不证明自然解锁 1／2。

Xorg `:99`、Godot 4.7.2/OpenGL3/Mesa llvmpipe，ffmpeg x11grab 25 fps、libx264 ultrafast/CRF18/yuv420p；[采集日志](shared-packed-continuous-ffmpeg.txt)与 ffprobe 核为 1440×900、10.000 秒、250 帧、H.264，无音轨；视频 SHA-256 `91bc3b63526a6417df48e75108f4451636c024a820cda07cbbecadd6caa70974`。先前仅检查 0／4／8 秒整屏和每秒接触表，虽完整 250 帧可解码，但原审进一步查出约 4.8–5.0 秒首次拾取引导覆盖核心；本录像保留为有缺陷的历史采集，不能作为无遮挡连续动态通过证据。问题源于驱动每 35 帧才调用公开 `dismiss_guidance`，首次拾取完成后主场景在下次轮询前显示了引导。后续修正采集见下。该软件渲染视频不作目标硬件性能验收，也未执行升级操作（升级证据见上段）。

[修正后的 10 秒连续录像](shared-packed-continuous-after-pickup-1440x900-25fps.mp4)仍用上述 `051cbd0d`＋`6d0ee146` 的相同 14 文件闭包、原八板及两张 packed mask；两张 `.import` 均保持 `process/fix_alpha_border=false`，公共运行代码未变。新版[录制驱动](shared-packed-continuous-after-pickup-driver.gd.txt)在正常 1× 预录阶段等待**真实**战场拾取事件使 `tutorial.completed("pickup")` 成立，再通过公开 `session.pending_guidance()`／`session.dismiss_guidance()` 完成提示链并确认主场景引导面板隐藏，才开放录制标记；没有修改游戏时钟或拼帧。录制期间逐帧检查 pending／面板，出现即记录 `VIDEO_UNEXPECTED_GUIDANCE`。本次[运行日志](shared-packed-continuous-after-pickup-runtime.txt)确认为 `pickup_completed=true`、`pickup_seen=true`、四路各 25%、1×、结束 pending 为空、无 `VIDEO_UNEXPECTED_GUIDANCE`／脚本错误；仍属受控四路可用，不代表自然 1／2 解锁。

[采集日志](shared-packed-continuous-after-pickup-ffmpeg.txt)和 ffprobe 核为 Xorg `:99`、Godot 4.7.2/OpenGL3/Mesa llvmpipe、ffmpeg x11grab／H.264 libx264 ultrafast CRF18／yuv420p、1440×900、25 fps、10.000 秒、250 帧、无音轨；新视频 SHA-256 `3e649abb4eabc8ea840e7a7da86553d4f89d6604624ccbe3c112553cc42c1e70`。已目视复看 0／4／8 秒整屏及每 0.25 秒全片接触表，完整解码全部 250 帧无错；进一步逐帧检查原提示覆盖区 `x250…489,y266…329` 的灰度均值：旧片最低 `73.42`（第 117 帧），新片最低 `177.03`（第 61 帧），没有旧片的遮暗突变。核心、四设备、导管和原生控制台在新片持续可见，战场继续推进。既有原 Astra 已按这条新片全片每 0.2 秒及关键 1× 帧审过：四路各 25% 持续工作阶段的核心、设备、导管动态可辨，原生控件与公共导航稳定、无引导遮挡，限此阶段可保；不外推少态动态、升级过渡、目标硬件帧率或新版装备同版跨页终验。

### 正式装备面板窄接当前公共组合

2026-10-31 只读核到装备组正式公共宿主运行源 `8430cd9c8cd84372e0218762daab986e989f3fbe`，装备分支证据 HEAD `9818145d97823c66dd26dc4968091f8fcc23dc0a`；其原入口 `workbench-optical-revision/inline-slot-workbench-concept/README.md` 固定 15 张正式宿主真整屏／操作，但仍待原审美术裁定。整体组当前 `design/clear-zone-host@a5da0606ba063fc3b7dccfb02d83eb9f3c25f03a` 已接 6d B01 14 文件闭包（本次逐 Git blob 全相同），装备仍为 4dd WIP。两树的公共 `zone_shell.gd`／`bridge_theme.gd`／`resource_visuals.gd` 及装备运行资产同版；正式装备相对 a5 的可消费运行差仅 `src/ui/equipment_panel.gd`（blob `9bc82d3afbfed4e70e77317bb9851677293eab09`）与**不能取**的隔离宿主 `src/main.gd`。本组在原工作区临时检出 a5，仅将该装备面板文件覆写为 8430；公共 main／导航／战场／Owner、B01 源和 mask 全保持 a5，完成后已恢复原分支。此为给整体组确认的最小组合，不提交他组生产文件、不视为整体已经正式合入。

首次 GUI 因新 `inline-{short,tall}.png` 导入缓存 `.ctex` 缺失报资源错误，原[预导入错误日志](r8436d-preimport-error-runtime.txt)保留；正常 Godot 4.7.2 editor [导入日志](r8436d-import-runtime.txt)后在**同一源码**重跑，[跨页驱动](r8436d-combo-driver.gd.txt)／[运行日志](r8436d-combo-runtime.txt)无脚本或资源错误，原生路由互斥。原尺寸已看[装备早2](r8436d-combo-equipment-1440x900.png)→[B01 真零](r8436d-combo-reactor-1440x900.png)→[B01 均分/MAX](r8436d-combo-reactor-max-1440x900.png)→[装备返回](r8436d-combo-equipment-return-1440x900.png)；原[装备阶段驱动](r8436d-equipment-states-driver.gd.txt)／[日志](r8436d-equipment-states-runtime.txt)另得同公共壳[中5](r8436d-equipment-middle-1440x900.png)、[晚8顶](r8436d-equipment-late-top-1440x900.png)、[晚8底](r8436d-equipment-late-bottom-1440x900.png)。中晚阶段通过原 Campaign／Equipment Owner 受控恢复换舰，非自然进度。装备空槽只留选择，B01 不被装备面板覆盖；x0–808 内区和 x808–855 导航在所看整屏无新越界。装备浅色工台与 B01 高亮舱室的跨页材质主次，整体原 Astra 已按 `07944449` 当前组合及本组 `2b057a21` 三张往返图核为固定静态组合无明确公共视觉缺陷；当前短图不代替动态、目标硬件性能或后续整组终验。

补核完整回路：[路由驱动](r8436d-route-driver.gd.txt)／[日志](r8436d-route-runtime.txt)以同一组合实际走 [B01 四路均分](r8436d-route-reactor-first-1440x900.png)→[装备早2](r8436d-route-equipment-middle-1440x900.png)→[B01 四路均分返回](r8436d-route-reactor-return-1440x900.png)，末态 Owner 仍四路各 `0.25`、装备隐藏、B01 路由选中；三张 1440×900 原尺寸已看，未见新越框或页面互盖。路由取图沿用整体驱动在状态准备后暂停 `game._process` 以固定整屏，**不是连续工作视频**；正常 1× 连续工作结论仍只属于前述 b689 片。先前一次不暂停尝试在战场新引导弹出时使装备路由被正常阻止，[原失败日志](r8436d-route-guidance-blocked-attempt.txt)保留；固定取图前按原 Session 接口完成引导，不改产品路由规则。

同组合另用[短窗驱动](r8436d-perf-driver.gd.txt)／[日志](r8436d-perf-runtime.txt)在真实拾取引导已完成、1×、四路各 `0.25`、1440×900/Xorg `:99`/Mesa llvmpipe/OpenGL3 下作 B01 可见→装备页隐藏 B01→B01 返回各约 6 秒：`23.78/28.15/31.43 fps`，B01 舞台 active 帧分别 `143/0/189`，游戏时间各推进约 6 秒；p95 为 `78.92/57.77/36.79 ms`。三窗战斗阶段与帧尾波动明显，数字只记录此组合页面显隐与动画 active 帧，不能从这些波动窗口推断 B01 净开销；不可作严格 B01 优化 A/B、目标硬件达标或新版装备最终性能保证。该短窗不记录系统 CPU 争用或战斗复杂度，不能事后把首窗低帧归于 B01；驱动在拾取引导完成后预热 `2.3 s`，三个窗口同一 Godot 实例、1×、不启用 ffmpeg，p95 仍顺序波动 `78.92/57.77/36.79 ms`。隐藏窗 `28.15 fps` 低于返回可见窗 `31.43 fps`，不能给出 B01 净成本。当前 packed＋按需 active 产品的较强同实例软件渲染定位证据为前述固定同相位 RGB 零差与正序 ABAB `31.29/31.61 → 32.33/32.23 fps`；反序 BABA 仅 packed 中间候选不能合算。最终硬件性能及少态动态另见后续证据，不宣称达到用户性能目标。


### 给整体组的最小接入闭包

[integration-closure.json](integration-closure.json)把已测公共运行基线 `051cbd0d` 与本组 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 的**14 个模块差异文件**逐一固定 Git blob 与 SHA-256：八张 `1187×1326` 源板、`live-material.gdshader`、`reactor_stage.gd`、两张 packed mask 与对应 `.png.import`。`reactor_scene.gd` 在两树 Git 对象相同；原三 mask 保留未改，公共 `main/zone_shell` 不在此闭包。整体组可按清单只取这些模块文件接新装备运行树，再按原 `y65`、`808×835`、导航 `x808…855` 核真实同版画面及性能；不要把研究 SVG/静态 PNG 当运行材质。装备 `art/equipment-materials-main-20261029@4dd4f1238ad59517965409b58eb52fb3acb14438` 已有矩形卡、短／长机库和 Owner 运行 WIP，但其原入口明确仍是旧公共宿主、最后补丁只解析且正式共享组合未完成；故本清单不把 4dd 当成已审装备新运行输入。需要装备原组固定完整可运行 SHA、整体组接入并给真实 2／5／8 装备及 B01 同版整屏／性能后，本组按具体接缝退点继续。

### 当前 packed 产品：少态与升级至真零的连续实机

本节两条录像复用已固定的公共运行 `051cbd0dc201fb53578d9c074460b8969a207ef8`＋本组 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` [14 文件闭包](integration-closure.json)，入口 `res://src/main.tscn`。八张原板、`live-material.gdshader`、`reactor_stage.gd`、两张 packed mask 及两张 `.png.import` 与闭包逐文件 SHA-256 一致；两张导入设置均为 `process/fix_alpha_border=false`。公共 main／导航／战场、正式 Owner、Excel 和配置未改。Godot `4.7.2.stable.official.ed1daf0bf`、Xorg `:99`、Mesa llvmpipe/OpenGL3、1440×900、正常游戏速度 1×；ffmpeg x11grab 连续采集、H.264/libx264 ultrafast/CRF18/yuv420p、25 fps、无音轨。两片均在真实拾取引导完成并经公开 Session 接口处理提示链后录制；驱动记录结尾无待处理提示，完整视频解码无错误，已看每 0.5 秒接触表和下列原尺寸关键帧。录像显示为真实墙钟运行，没有拼接静帧或修改游戏时钟。Godot 日志仅有 Mesa 不支持运行中切 V-Sync 的警告，无脚本错误。

[受控 1／2／3 连续片](shared-packed-controlled-123-1440x900-25fps.mp4)为 `22.000 s/550` 帧，SHA-256 `01451aa53afde3977b11cabbdb8b61da96e86aa83a1005429330e3010cb96c2a`；[驱动](shared-packed-controlled-123-driver.gd.txt)、[Godot 日志](shared-packed-controlled-123-runtime.txt)、[采集日志](shared-packed-controlled-123-ffmpeg.txt)记录单路仅炼铁 `100%`、双路武器／炼铁 `50/50%`、三路武器／盾甲／炼铁 `34/33/33%`，每态正常游戏时间及舞台相位分别推进约 `3.00/3.00/3.02 s`。原尺寸[单路](shared-packed-controlled-1-active-1440x900.png)、[双路](shared-packed-controlled-2-active-1440x900.png)、[三路](shared-packed-controlled-3-active-1440x900.png)显示相应机器、管路、连续控制井、原生行和工作光，无多余设备空槽。视频起段含四路预录过渡，后段四路购级与低载操作未保证在 22 秒截点内完整呈现，**本片只证明受控少态连续工作**。1／2 使用隔离 Reactor Owner 的 `reactorModules` 输入，不是自然解锁；三路也在此片按同一受控条件采集。原 Session Owner 随后恢复四路，不把隔离 Owner 发布当作完整 Session/native 游戏进度验证。

[四路购级至真零连续片](shared-packed-upgrade-zero-1440x900-25fps.mp4)为 `18.000 s/450` 帧，SHA-256 `55ace5814a30231cfad81eef363b2dce899e0230b208f56ea520b76dfb4d1551`；[驱动](shared-packed-upgrade-zero-driver.gd.txt)、[Godot 日志](shared-packed-upgrade-zero-runtime.txt)、[采集日志](shared-packed-upgrade-zero-ffmpeg.txt)记录在四路各 `25%` 下，公开 Economy 受控预存铀以覆盖交易，真实鼠标选循环 `×10` 再点独立升级键，等级 `1→11`、实际扣 `550` 铀，交易前钱包 `3025`、成交后 `2475`，原生回执“已升级 10 级”。之后通过正式 Owner 公开分配入口把武器设为 `1/5766`，其余设零：负载 `0.00017343045439`、原生标签 `<1%`，舞台相位在约 `2.83 s` 正常游戏时间内继续推进；真零 `0%` 时游戏时间继续约 `3.02 s`，工作相位增量为 `0`。原尺寸[升级前](shared-packed-upgrade-before-1440x900.png)、[成交回执](shared-packed-upgrade-purchased-1440x900.png)、[低正载](shared-packed-upgrade-low-1440x900.png)、[真零](shared-packed-upgrade-true-zero-1440x900.png)来自同片，未见新提示遮核心。短于 18 秒的试录在真零稳定段前截止，未作为本节最终证据；本片的 `18 s` 已包含该段。钱包初值受控且战场有正常掉落收入，`3025→2475` 是本次交易紧邻断言，不把它当自然玩家预算。

两段片的状态切换由驱动发出公开 Owner 命令或真实原生按钮鼠标事件，源代码本身不添加新玩法。上述四路连续工作阶段已经原审按 `b68994bb` 限定通过；本节新增的**少态连续效果和升级过渡**已由既有原 Astra 全看两片及七张关键帧，确认 1／2／3 设备、管路、控制行对应，升级／低正载／真零可读且无遮挡，限代表状态视觉可保，不代替自然 1／2 解锁、目标硬件性能、装备新版动态或整组终验。性能定位仍取前述同实例正序 ABAB；录制视频与 `2b057a21` 三短窗都不是目标硬件帧率达标证据。

### 当前固定公共版交原审：新增动态范围与余项矩阵（2026-10-31）

最新只读固定运行树为整体 `design/clear-zone-host@a037ecbf5b9bf046d0da5c8101751fa1343667ab`，其 `main.tscn` 是正常入口；与本组 [14 文件闭包](integration-closure.json)逐个 Git blob 相同，正式 `equipment_panel.gd` blob 为 `9bc82d3afbfed4e70e77317bb9851677293eab09`，公共 `zone_shell.gd` blob 为 `8998e38d746b31f7f676fdbc0126906c79e0863d`。整体 `07944449325c9379981e8382be697ce840eadcef` 到 `a037ecbf` 的 `src/`／`assets/` 无变化。因此**当前 B01＋正式装备＋公共资源条已经是同一固定运行源码**，上文时间线中“待正式装备面板接入”或“装备仍只有设计稿”只指旧阶段，不能作为现版阻塞。既有整体原 Astra 对该静态组合九整屏与三往返图已给固定范围无明确公共视觉缺陷的结论；本组不复拍这些图、不改公共壳或合 main。

给既有原审续核的新增对象只含两片，均基于与现整体公共树逐 blob 相同的 B01 产品闭包、正常 `1×`、1440×900/25 fps：

| 已审代表状态 | 固定实机入口 | 原审结论与范围限制 |
|---|---|---|
| 少态连续动态 | [受控 1／2／3 片](shared-packed-controlled-123-1440x900-25fps.mp4)及[日志](shared-packed-controlled-123-runtime.txt) | 分别核单炉、双武器＋炉、三武器＋盾＋炉的核心／实体／各自导管光随正常时间连续可读，原生控件与公共导航不遮挡；各态游戏时间／相位各推进约三秒。1／2／3 均为隔离 Owner 受控状态，不判自然解锁。该片末尾的购级／真零不作本片主张。 |
| 真实购级至真零过渡 | [18 秒片](shared-packed-upgrade-zero-1440x900-25fps.mp4)及[日志](shared-packed-upgrade-zero-runtime.txt) | 核真实鼠标循环 ×10／独立升级，等级 `1→11`、铀 `3025→2475` 扣 `550`、提示“已升级 10 级”；随后 `<1%` 正载工作光仍推进，再到真零 `0%`、游戏继续而相位停止。预算有公开 Economy 受控入账，不判自然初始余额。 |

两片完整视频和对应驱动／采集日志／关键帧均已归档于上节；本节只给原审明确的固定对象，不开启新审核或重录。旧 `b68994bb` 四路各 25% 的 10 秒动态已获限定原审，可直接沿用；受控 1／2 鼠标、四路接纳／拒绝／×10／MAX、静态八态和跨页往返证据也已在本入口固定，无须因这两片重做。

| 事项 | 当前边界与责任 |
|---|---|
| B01 静态八态端部、原生行与装备同壳跨页静态 | 既有原 Astra 分别按 `b178ec39` 与整体 `07944449`／本组 `2b057a21` 固定图作限定可保；不再列缺。 |
| 四路 25% 正常连续动态 | `b68994bb` 固定 10 秒无遮挡片已获限定审结论；不再列缺。 |
| 当前 packed 版少态动态、真实升级过渡 | 原 Astra 已全看上表两片＋七张关键帧：受控 1／2／3 设备／管／行对应，升级、低正载、真零可读且无遮挡；**代表状态视觉范围关闭**。与既有四路片合成当前 B01 可评价视觉稿；不扩为自然 1／2 解锁或性能验收。 |
| 功能与性能 | 公开 Owner/真实鼠标链、同相位 `674,680` RGB 零差和**最终 packed＋按需 active**正序 ABAB `+1.04/+0.62 fps` 已测。`2b057a21` 三短窗波动不能推 B01 净成本；本环境无新明确可保画质且有稳定收益的独立热点。用户目标设备/门槛未在本证据中固定，故不宣称硬件达标；这不阻当前软件渲染版交审。 |
| 自然 1／2 关卡 | Excel 无前两路独立门槛，用户已指示源表没有就暂不改。受控状态只覆盖视觉／操作；自然流程不在本版声称范围，也不擅增规则。 |
| 整组最终版 | 现公共树已含 B01＋正式装备；仍由整体组按星球等其余模块的新运行输入及原审结果收全页，B01 只按明确退点修其所属源图／代码。装备已送用户的五图反馈属装备组，不作为本组新增测试或新素材前提。 |

### 当前受控环境性能调查的有界结论

**调查范围已完成，用户性能目标尚未验收。** 当前公共运行版 `a037ecbf` 已含本组相同 14 个 B01 blob，运行入口为 `main.tscn`；在现有 Xorg `:99`、Mesa llvmpipe/OpenGL3、1440×900、正常 1×／四路各 25% 条件下，已把可独立定位且可保持效果的 B01 高成本路径落地。先在静态控制台区域跳过无用工作场，再在 mask 为零或相应负载为零处跳过昂贵动态函数，旧单活实例短窗由 `25.31/21.08` 到边缘版 `33.48/27.88 fps`（不录／录制），隐藏页 `32.89→34.67 fps`；这是当时同环境前后定位，非当前公共壳严格 A/B。当前 packed mask＋按需 active 采样**组合成品**与对应基线在同一实例正序 ABAB 得 `31.29/31.61 → 32.33/32.23 fps`，收益 `+1.04/+0.62 fps`；固定相位 B01 完整舞台 `674,680` 个 RGB 像素差为 `0`。反序 BABA 只测 packed-only 中间候选，不能并入组合产品收益，也不能把同相位零差扩大成所有交互或动态帧的逐像素保证。

已核 UI model／quote／preview／commands 在正常可见窗口为 `0` 次、节点稳定 `53`，无高频控件重建；相位写入使整块动态材质持续工作，是已确认主要成本路径。诊断中冻结相位 `45.66 fps`、廉价材质 `39.71 fps` 仅显示成本归属，均撤销，不作为产品降帧／降质方案。椭圆框早退虽同相位零差但 ABAB 无稳定收益；8 位预计算几何虽约快 `1 fps`，边缘最高差 `61` RGB 级；浮点几何要约 `11 MB` 新纹理只得约 `0.5–1 fps`，半精度约 `5.2 MB` 且收益不稳，均未纳入。此前三短窗 `23.78/28.15/31.43 fps` 的战场和帧尾波动、CPU 争用未同步记录，隐藏窗竟低于返回可见窗，不能归因 B01。现无另一个已定位、可复核且保同版画质／刷新／交互的独立优化点，故不再重复噪声采样或用诊断冻结态冒充完成。

本软件渲染结果**不证明用户机器已达帧率目标**；目标机器未观测是证据限制，不是无限继续实施的待办。若用户在当前版仍实测约 `10 fps` 降幅，最小复核输入是固定运行 `a037ecbf`（14 个 B01 blob 已同本组 `6d0ee146`）、其 Godot/native 运行版本、实际 GPU／驱动与 renderer、窗口分辨率及录屏开关，以及同一战斗时刻四路 `25%` 的 B01 可见→装备页隐藏→B01 返回帧时间／CPU-GPU profile；同时记录倍速、提示面板、可见路由和后台争用。凭这些可定位是否是硬件上新增的 shader、纹理带宽、战斗或录屏瓶颈，再决定具体修复；在得到这些数据前不宣称达标，也不臆定还存在一项可做的 B01 代码修复。

### 当前完整视觉候选已交用户看效果（状态登记）

根端已将本组 `implement/reactor-centered-godot@808253769aa381560d6b0377785543eaacce711b` 的当前完整 B01 视觉候选实际送用户请求效果确认；根所交的是同一固定公共树 `design/clear-zone-host@a037ecbf5b9bf046d0da5c8101751fa1343667ab` 所含相同 14 文件 B01 运行闭包的三段真实视频：[四路各 25% 正常连续工作 10 秒](shared-packed-continuous-after-pickup-1440x900-25fps.mp4)、[受控 1／2／3 正常连续工作 22 秒](shared-packed-controlled-123-1440x900-25fps.mp4)、[四路真实购级到低正载／真零 18 秒](shared-packed-upgrade-zero-1440x900-25fps.mp4)。前述既有原 Astra 已对三段各自限定范围给视觉可保结论；当前是**完整视觉候选待用户意见**，不是用户已确认、自然 1／2 解锁验收、目标机器约 `10 fps` 降幅已消或整游戏任务通过。用户机性能未测的证据限制已随候选告知，现阶段无已定位的 B01 独立性能修复待做；不合 main。本节只记录根已完成的交付事实，本组未另发消息或 Library 文件。

### 用户返修一：原生控制区与公共数字（已完成源码，待整体视觉复看）

本组 `implement/reactor-centered-godot@e2b58e6acbd0ae0c17b53acfa7d67295e6597213` 只改 `src/ui/reactor_scene.gd` 的 B01 控件和定向消费整体 `design/clear-zone-host@f688ea7c8856ad87775b0853044b9020303b8137` 已固定的 `src/ui/player_text.gd::number(String)` 展示函数；本组函数块与整体源逐字相同，不取公共 `main/zone_shell/economy`。均分原 `Rect(655,560,94,36)` 的图形压金色端框，现缩为 `Rect(670,565,60,26)`，完整贴面落入原按钮内腔；费用唯一当前资源铀的彩色图标移至 `x612` 与“等级”标题同左沿，金额起 `x642`，不再常驻独立“资金不足”行。当前 quote 的唯一铀资源不足时金额文字红 `#e44b3a`，图标保持 `ResourceVisuals.icon_modulate` 原色；Owner 报价返回 `can_purchase=false/reason=InsufficientResources` 时升级键仍可点，实际点击 `purchase/purchase_max` 的 Owner 拒绝才短示“资源不足”。数量键仍仅切 `×1/×10/MAX` 本地报价，升级键仍是独立真实执行；非预算报价错误仍禁执行。报价及金额只格式显示，不将 `PlayerText.number` 的 `k/m/b/t/kt/e` 文本回传 Amount 运算。本轮权威反应堆费用只有单铀，故其 quote 可付布尔值恰对应唯一费用项；若未来增加多资源须由 Owner 报价补逐项可付信息，不能猜格式化字符串当 Amount 逐项比较。装备及其他模块仍归各自原组，不能据此说“全模块不足”已实现。

同一工作区临时检出整体 `f688ea7c`，只覆写本组上述 `reactor_scene.gd`（文件 SHA-256 `926fa49456462ab55da0e4ea445a88b943c7dee68540ef32d4602b9fa49f1639`），`PlayerText.number` 函数块与 f688 同源，公共 main／导航／Owner 保持不动；Godot `4.7.2.stable.official.ed1daf0bf`／Xorg `:99`／Mesa llvmpipe／OpenGL3／1440×900／1×。借用 native 清单并按正常 editor import 后 `--check-only` 无脚本错误。[受控驱动](return-ui-shared-controlled-driver.gd.txt)和[运行日志](return-ui-shared-controlled-runtime.txt)核 1／2／3／4 Owner 零态与均分、1／2 真鼠标拖动回读，均分键在四态同一内腔；下列整屏只用于检查**当前原生 UI**，舞台沿用已被用户退回的整图动态，不能当新结构证据。

| 可用路数 | 真零整屏 | 均分整屏 |
|---|---|---|
| 1 炼铁 | [图](return-ui-shared-1-zero-1440x900.png) | [图](return-ui-shared-1-active-1440x900.png) |
| 2 武器＋炼铁 | [图](return-ui-shared-2-zero-1440x900.png) | [图](return-ui-shared-2-active-1440x900.png) |
| 3 武器＋盾甲＋炼铁 | [图](return-ui-shared-3-zero-1440x900.png) | [图](return-ui-shared-3-active-1440x900.png) |
| 4 全部 | [图](return-ui-shared-4-zero-1440x900.png) | [图](return-ui-shared-4-active-1440x900.png) |

[不足驱动](return-ui-shared-budget-driver.gd.txt)与[同版日志](return-ui-shared-budget-runtime.txt)实点 MAX 买 14 级后钱包余额 `134`、下一级报价 `668.0 铀`；[点击前](return-ui-shared-insufficient-before-1440x900.png)费用红、升级可点，点击后 [整屏](return-ui-shared-insufficient-click-1440x900.png)由 Owner 拒绝 `InsufficientResources`、才出“资源不足”。切 MAX 零可购时[整屏](return-ui-shared-max-zero-1440x900.png)报价空成本显示“—”、执行键仍可点，点击同样由 Owner 拒绝。`100.0/100.0` 与 `10.0 铀` 是公共新数字函数展示，Owner canonical Amount 未改。现已返回原分支并恢复临时覆写；当前 UI 真组合源需随新可组合舞台一起再作最终视觉验收，不将旧管线背景重复送审。

### 用户返修二：可组合 B01 舞台的当前实现与验证边界

已核本地 Blender `4.3.2`、Inkscape、ffmpeg 和 Godot `4.7.2` 可用。退回前 `reactor_stage.gd` 以整张板画设备及导管、再由 `live-material.gdshader` 用 mask 覆盖工作场，产生错管光和连接穿帮。**本次制作树**已改为独立背景、核心、四机体、四根双层实体管、前法兰、核心钳臂／转子及单独控制台壳；运行阶段不再实例化旧整图或旧 `live-material.gdshader`。批准主体体量与原生控制台空间沿用。旧资产、三段旧视频和其性能数字仅作历史对照，不能代表本次新结构已获用户验收。

源画布仍为 `1187×1326`，显示域 `x0…807,y65…899`。`modular-bay-background.png` 只承载舱壁地坪，`modular-core.png` 和四张 `modular-{weapons,defence,smelting,condensation}.png` 为分别裁出的机体；源层分别在 `modular-core-source.png`、`modular-modules-source.png`，可用 [装配脚本](../../../../assets/ui/reactor/b01/assemble_modular_surfaces.sh)重建裁切。四路管的**同一** Blender 双层截面与金属／玻璃／金色环箍由 [生成脚本](../../../../assets/ui/reactor/b01/generate_modular_pipes.py)沿各自 Bézier 端点和切线放样；每路产出独立 `shell` 和 `front` 透明层，运行时中间另有沿弧长 UV 的定向内腔光 Mesh。核心和设备在管前绘制，盖住各自交接边；原生 HSlider／按钮／文字保持在分离的控制台壳之上。源图由生成资产切片提供表面质感，代码和 Blender 路径持有部件、端点及动画；没有把整张新图再当设备／管路 mask。

实际端点／切线合同在 `reactor_pipe_view.gd::ROUTES` 与 Blender `PATHS` 同值：武器 `(448,249)→(318,208)`、盾甲 `(741,247)→(916,199)`、炼铁 `(463,450)→(313,517)`、凝聚 `(729,446)→(889,518)`，中间两控制点也逐项固定。各自 `PIPE_BOUNDS` 仅给裁后实体层定位；弧长 UV 与载荷／相位则只作用于对应管腔。1／2／3／4 仅挂对应部件／管，少态控制井保留原生行；零载保留静态实体，关闭局部工作光。未开放方位在核心自身的结构法兰上仍可能看见硬点，是否足够像封闭建筑需结合实机整屏审，不能以代码断言视觉通过。

运行阶段 `reactor_stage.gd` 持有四个 `PipeView`、四个 `ModuleView` 和独立核心场／转子／双钳臂。Owner `load` 控制核心离散产生和约束运动、对应管腔沿弧长从核心向设备前进的光包、武器双炮、盾面、炉内熔流和晶体腔四种局部动作；真零关闭所有局部工作光，少态隐藏未开放件。钳臂按 5.2 秒周期压合、停驻、释放，转子单独转动。`game_time/paused/visible` 生命周期、Owner 分配／报价／升级、Session/native 和公共导航未改；本次只替换 B01 舞台绘制。当前受控八态与四路 1× 连续片在下段固定后再请原视觉审核，**旧 Astra 对旧整图的通过不外推**，新结构性能尚无可比采样。

**已观看的真实游戏动态参考，仅支撑机械约束运动。** PIndustries 的 [Arkline / Ship Pioneer 开发记录](https://github.com/PIndustries/arkline-engine/wiki/Ship-Pioneer)所附[反应堆机制实机动图](https://raw.githubusercontent.com/PIndustries/arkline-engine/7e82a0690aab21a9d10cde906140f75393931031/docs/ships/pioneer/images/progress-20261024/pioneer-raised-bridge-reactor-mechanism.gif)由项目作者标为 `100 ms authority replay`／真实注册几何（2026-10-24）。从公开 Git 对象正常取得完整 `1280×720`、94 帧／9.4 秒 GIF，SHA-256 `942742715ff8fde0ee27eea448d235f9f80b5baf129ee75da696edbc470271b7`；已看每 0.5 秒接触表和原尺寸 2／4／6／8 秒帧。约 1–4 秒，多道刚性颊／束带沿同轴导轨向稳定中心压合并在 100% 紧缩处短暂停住；约 5–6 秒按原机械轨迹张开，7 秒后切到只读控制屏。借鉴的是**中心定形、独立机械束缚件有行程和停驻**，不照搬其低多边形材质、画面构图或编辑后的停帧。片中没有可信的能量管内流和端口反馈，因此**不能**把它当管路／能量动态证据。

**已观看的核心产能动态参考，仅支撑离散反应事件。** WestonBDev 的开源 Unity [Nuclear Reactor Dynamics Simulator](https://github.com/WestonBDev/nuclear-reactor-simulator)在固定 Git `5a48a28b2437fec509acc2d5b201e68437cda2c2` 内提供[真实 Game-view 高活性核心动图](https://github.com/WestonBDev/nuclear-reactor-simulator/blob/5a48a28b2437fec509acc2d5b201e68437cda2c2/Documentation/Media/unity-reactor-excursion.gif)，`1080×608`、56 帧／6.72 秒，SHA-256 `ba11f53d16e72e66bfdd51b1cacaa47abd2ff9554592d0e9808390a5583dd49b`；已看完整每 0.5 秒接触表。0–6.5 秒中蓝色燃料位置固定，亮／暗离散粒子移动、相遇与增殖，粒子数随活性逐步上升，而吸收棒几何保持独立。借鉴**固定约束内的离散生成、捕获和向出口传递**这一时间关系，不把科学可视化的二维点阵当最终美术，也不把它当游戏 B01 的物理公式或已验证管路外形。公开仓库说明 GIF 来自 Unity Game view；这里的观察限于所见画面。

另查 Coffee Stain Studios 的 [Satisfactory Update 4 官方 Steam 预告条目](https://store.steampowered.com/app/526870/Satisfactory/)（Steam trailer id `361661`）和 Digital Extremes 的 [Warframe Reactor Sabotage 官方介绍](https://www.warframe.com/en/news/attention-pc-tenno-33)，但当前 Steam 视频 CDN 和 Pixor CC0 动画 GIF 直取遭 `CONNECT 403`，web 视频入口不可播放；这两项**未看过动态**，不得据文字或静图虚构管流效果。后续核心产能／沿实体管输送／端口设备回应必须用实际可运行新分层舞台观察与验证；若再引外部运动范例，先看完整动态并记录观看段。

**当前新结构的受控实机包。** 运行源码与图／片保存在本节所在 Git 提交，旧公共 `main.tscn` 宿主、Godot `4.7.2`、Xorg `:99`、Mesa llvmpipe/OpenGL3、`1440×900`、正常 `1×`。受控 [驱动](modular-controlled-driver.gd.txt) SHA-256 `5058b648ddb12edcd8c329a53132105878c35554823d3c096549a5708f269e4b` 只在隔离 Owner 复制 `reactorModules`，不改正式 Excel／自然解锁；[日志](modular-controlled-runtime.txt) SHA-256 `682732562aac305b471041c758ef86d009e56c8dd2d2375c8551f54bb6a65b58` 记下八态模型、stage loads、原生行显示及 1／2 路真实鼠标拖拽被 Owner 接纳。各整屏为实际 Godot viewport，不是贴图合成：

| 受控可用集合 | 真零、实体仍在 | 原生均分、工作光 | 鼠标手分并回读 Owner |
|---|---|---|---|
| 1 炼铁 | [整屏](modular-controlled-1-zero-1440x900.png) | [整屏](modular-controlled-1-active-1440x900.png) | [整屏](modular-controlled-1-manual-1440x900.png) |
| 2 武器＋炼铁 | [整屏](modular-controlled-2-zero-1440x900.png) | [整屏](modular-controlled-2-active-1440x900.png) | [整屏](modular-controlled-2-manual-1440x900.png) |
| 3 武器＋盾甲＋炼铁 | [整屏](modular-controlled-3-zero-1440x900.png) | [整屏](modular-controlled-3-active-1440x900.png) | — |
| 4 全部 | [整屏](modular-controlled-4-zero-1440x900.png) | [整屏](modular-controlled-4-active-1440x900.png) | — |

[新结构四路工作预览片](modular-preview-10s-1440x900-25fps.mp4) SHA-256 `fed5c8d18b87deae67d35187eea4c20f062d8bd42e9f8b1169aa6b4350befed0` 为真实游戏 `1×` 连续 `10.00 s`、`250` 帧、`25 fps`；[驱动](modular-preview-video-driver.gd.txt)／[日志](modular-preview-video-runtime.txt)说明四路 `25%` 和主场景已正常关闭引导，观察的 0／4／8／9.8 秒关键帧可见机械转子／钳臂、各机体与管腔运动，未见引导遮页。日志 `VIDEO_END wall_seconds=35` 是驱动遗留**硬编码文字**，实际驱动执行 20 次一秒定时并由 ffprobe 核片长 10 秒，不能把 `35` 当实测时长。**版本限定：**该片在本次最后一轮 Blender 资产再生成前数分钟录得；之后相同生成脚本重出透明管／转子贴图，并用上表当前资产实际重跑八态。片子仅作新结构运动预览，不能冒充最终资产的逐帧同源连续片；当前资产新的连续片尚无。`generate_modular_pipes.py` SHA-256 `1df0308235f675f1819d2c2f21e82eaddc022534efd464a814ec73481426da66`、`assemble_modular_surfaces.sh` SHA-256 `ee3945dc2a7d844f62a5c72bbb5d66966d0ad7f21bd1844c955c05e8490b4034`，三张源图 SHA 分别为背景 `65ec38308fa8f7e376b8b50769d0ea0b54758a9fd88435653914321198e40dfc`、核心 `cb623fd94dd6e433a6507a073e9e98e6777abe8c66d69b4e729f979ecb656295`、四机体 `3f787d1467346b1b38971d1ad5513cc9c10d6165ac997419c0b7891105e4e9f7`。原独立 Astra 尚未审此新结构，也没有新架构性能配对；八态图只证上述受控显示／点击范围，不证明自然 1／2 解锁或用户目标机性能。

### 性能完整对照：上次已报告记录 → 本次状态

本次仅把原已测数据补齐为同口径报告，**没有新采样，数值不更新**。上次用户已收到的产品对照是公共 `051cbd0dc201fb53578d9c074460b8969a207ef8`＋本组 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 当前 packed＋按需 active 组合，在 Godot `4.7.2`、Xorg `:99`、Mesa llvmpipe/OpenGL3、`1440×900`、正常 `1×`、四路各 `25%`、**不录屏**的同一实例 6 秒 ABAB；[驱动](performance-packed-active-abab-driver.gd.txt) SHA-256 `4898608634d6a9ac7f5f59da669360f72e9d28c67a077e7548a907978b3b8162`，[原日志](performance-packed-active-abab-runtime.txt) SHA-256 `226900128b9ca4320d629cae1af347268d2e46bada65537f9e5390d36626eef8`。四窗各游戏时间／材质相位约推进 6 秒、节点 53 不变，战场自主进程不是同一冻结帧；故这说明该环境同实例短窗趋势，不是战斗完全同帧的净成本分离。

| 已报告配对 → 本次 | 基线 FPS／平均帧 ms／p50／p95 ms | 当前组合 FPS／平均帧 ms／p50／p95 ms | 可比范围 |
|---|---|---|---|
| 第一次 B→A → 数值未更新 | `31.29 / 31.96 / 30.812 / 36.627` | `32.33 / 30.93 / 30.099 / 35.771` | 同实例相邻 6 秒；`+1.04 fps`，角色/负载/分辨率/录制状态相同，战场仍自主变化。 |
| 第二次 B→A → 数值未更新 | `31.61 / 31.64 / 31.048 / 36.987` | `32.23 / 31.03 / 30.161 / 35.763` | 同实例相邻 6 秒；`+0.62 fps`，同上。 |

现 UI 文件 `e2b58e6a` 和公共数字源 `f688ea7c` 相对上述已报告测量有源码／文字变化，本轮没有用它们重测；不能暗把旧 FPS 当新 UI 或未来可组合舞台的实测。原 shader 收益来自三 mask 打包成两张 RGBA（导入 `fix_alpha_border=false` 保零 alpha 处 RGB）并在无工作权重处跳过 active 底图采样；四路固定相位 [前](performance-packed-baseline-same-phase.png)／[后](performance-packed-candidate-same-phase.png)的 B01 舞台 `674,680` RGB 像素差为 `0`，只证明该相位现旧舞台画面保持，不外推动态或新结构。反序 BABA 是仅 packed mask 中间版，不能与上述最终组合正序拼成一组保证。其他淘汰方案（椭圆早退无稳收益、8 位几何边缘失真、较大浮点几何纹理收益有限）与已修静态控制台／mask0 昂贵场分支见上节；冻结相位／廉材仅诊断，产品全效果不降级。

模块显示／关闭的**严格同战场同条件净成本**在当前最终组合上尚无可靠配对：`2b057a21` 同构建的可见→装备隐藏→可见 `23.78/28.15/31.43 fps` 是顺序不同战斗时刻和不同页面 UI，不能差分成 B01 独占开销；旧 `34.67/32.89 fps` 分属旧版／旧宿主，仅历史，不与当前配对。目标机器、其 renderer、实际分辨率、录屏状态与同场 profile 均未观察到，不能声称用户所报约 `10 fps` 损失已消。后续新可组合舞台会改变源码、纹理/mesh 与画面，届时需单独同版本性能证据；本轮没有以现旧 shader 报告为新架构背书。
