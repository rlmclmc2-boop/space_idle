# 反应堆 B01 整模块重设计：当前唯一设计入口

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
本入口对应 `implement/reactor-centered-godot` 从 `01efbf12e7c2d8a814343fe7503fd692861f4712` 延续的候选；原旧入口：../ship-hub-r9/README.md。本目录保留 `00971d36` 的原四路录像/早期性能与报价图作为历史对照；当前源码新增受控单／双路舱室、无损 shader 优化和原舞台左右收边。下方“整屏统一与合法模块数交接”列出当前源码的八态整屏、最新交互与性能证据；不能把旧录像或旧报价图写成这一版动态验收。

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

用户已退回装备与反应堆的跨页语言及左外缘、右侧导航交接；本组的局部图和性能采样不代表该整屏问题通过。当前反应堆源码为 `587cf2f9f99d1cf06d8b3fb8e62c1aef6dd72fa2`（相对 `eea1a7e6` 只改真零证据）；2026-10-30 核到的整体远端 `design/clear-zone-host@61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1` 的运行树接了同一 `eea1a7e6` B01 源码。整体分支后续跨页字体 R3 是静态设计预览，尚非固定运行材质或左右边界协议。该分支的完整[反应堆](https://github.com/rlmclmc2-boop/space_idle/blob/61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/eea-combo-reactor-1440x900.png)和[装备](https://github.com/rlmclmc2-boop/space_idle/blob/61c9cdbcef596037d0c6e8be1e6f94ae0fdb57b1/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/evidence/eea-combo-equipment-1440x900.png)是已存在的同壳运行图，供定位退回问题；不是新版统一已通过证据。本分支的整屏图仍在旧 `main.gd` 宿主下取得，不能冒充整体组合。

| 可见模块数 | Campaign／Owner 合法来源 | 本组现有整屏与结论 |
|---|---|---|
| 1 | 用户描述初开放仅炼铁，但现行 Excel 未列单独门槛、Owner 实际同时开放前三路；自然关卡尚无该状态。 | **受控隔离 Owner 输入**仅 `smelting`：[真零](controlled-one-zero-1440x900.png)及[均分 100%](controlled-one-active-1440x900.png)；武器、盾甲、凝聚实体／管路／工作光及控件行、总条段均无。此图不冒称自然进度。 |
| 2 | 当前 Excel 未声明中间两路关卡；不推断自然可达。 | **受控隔离 Owner 输入**`weapons,smelting`：[真零](controlled-two-zero-1440x900.png)及[均分 50/50](controlled-two-active-1440x900.png)；盾甲、凝聚实体／管路／工作光及控件行、总条段均无。此组合只是覆盖 2 路布局与分配，不新增玩法。 |
| 3 | 当前 `Reactor.refresh_availability` 在反应堆可用后无条件启用武器、盾甲、炼铁，只有凝聚查询 Campaign；这只描述当前实现。用户描述下一关武器、盾甲加入，源表尚未声明这一步。 | 原正式 Owner/Campaign [真零](locked-zero-1440x900.png)与[三路均分](locked-active-1440x900.png)为 34/33/33%、100/100；最新边缘版另有[受控真零](controlled-three-zero-1440x900.png)和[均分](controlled-three-active-1440x900.png)。右下未开放设备、管路、工作光与第四控制行/紫色段均无。 |
| 4 | 当前 Owner 在凝聚可用时加入第四路；Excel 凝聚门槛为 cleared 关卡 15。 | 原正式 Owner/Campaign [四路真零](true-zero-1440x900.png)与[四路均分](active-1440x900.png)各 25%、100/100；最新边缘版另有[受控真零](controlled-four-zero-1440x900.png)和[均分](controlled-four-active-1440x900.png)。[×10 报价](ten-1440x900.png)、[MAX 报价](max-1440x900.png)及[成交](ten-purchased-1440x900.png)记录升级区与按钮行为。 |

**纠正 `f33ed6c` 的错误推论：**运行配置 `generated/config.json`（本工作区 SHA-256 `308b8f8089750db99e0190526f2f1fde91ee2950c5229567d295860b04d077de`）和 `src/systems/reactor.gd::refresh_availability` 只能证明现行实现把前三路同时开放，不能证明它符合设计。用户明确初开仅炼铁、下一关再开武器与盾甲；1 路为用户要求覆盖的设计状态，2 路不能只凭当前 Owner 策略排除。现有受控 Campaign 恢复图只说明当前运行态，不是自然关卡顺序实测。三路／四路均分和 ×10／MAX 的 Owner 状态、原生控件及鼠标操作由本目录日志支持；最终整体组合中的均分视觉、控制台主次与跨页统一仍待核。

2026-10-30 源链复核：运行配置源 `config_excel/unlock.xlsx` SHA-256 `ee216e7524e918279a967220c1a205cfd433fe2c9c389c2a7f2a2a35525b2ed7`，`unlock` sheet 第 15 行是 `feature/reactor, level=1, mode=cleared`，第 31 行是 `reactor_module/condensation, level=15, mode=cleared`；全表没有 `reactor_module/weapons`、`defence` 或 `smelting` 行，也没有别名行。`foundation/import_excel.py` 调用 `config_tools/compile.py::compile_config`，现行 `generated/config.json` 同样只有上述反应堆开放行，故**不是导出漏行，而是 Excel 源没有声明前两路门槛**。`Campaign.available(kind,target)` 只按 `type/target` 精确匹配、满足 `cleared_stages` 或 grant 后返回 true，缺行会返回 false；`Reactor.refresh_availability` 第 64 行以 `module != "condensation" or unlocked(...)` 把武器、盾甲、炼铁无条件加进可用集合。Session 创建时 `game_session.gd:112`、恢复后 `:230`、进度发布 `:1359` 都调用该刷新；`Reactor.presentation_model` 带 `_enabled`，`reactor_scene.gd::_refresh` 仅显示 enabled 行并据此更新 stage。因此现行实现是 cleared 关卡 1 后直接三路，与用户描述的“初开炼铁、下一关再加武器盾甲”不同；由于源表无该条件，按用户限制**暂不改正式 Excel、导出配置或 Owner 解锁规则**，也不把“下一关”擅定为具体关卡数。受控验证从同一参数复制仅换 `reactorModules` 输入，在隔离 Reactor Owner 上调用公开 `refresh`、`apply_allocation_plan`，并通过原生 UI 均分键调用 Owner `distribute`；原 Session 及其正式 Owner 保持原样。[受控驱动](controlled-states-driver.gd.txt)与[四态日志](controlled-states-runtime.txt)记录每态 Owner `modules/load/ratio`、UI 行集合、stage 负载和按键状态。隔离 `publish` 只接受该 Owner 候选，不证明整场 Session/native 因子发布或自然解锁流程。1／2 为受控显示与分配证据，3／4 另有上述现行 Campaign/Owner 整屏证据。

**性能仍待用户目标硬件与最终共享组合验收。** 此分支继续保留 shader 静态控制台 `uv.y >= 0.58` 跳过无效工作场计算；新增在对应纹理 mask 为零或 Owner 负载为零时跳过该管路／机器昂贵动态函数，仍逐帧推进相位，保留完整四路材质、工作光与业务逻辑。此版又在同一舞台 shader 的最终颜色将左右 24px 平滑收至公共深蓝 `#0d2533`，不加模块外装饰层，中央主体不受影响。此前 `587cf2f9` 单活实例 8 秒[基线日志](performance-current-runtime.txt)为不录制 25.31 fps、录制 21.08 fps、隐藏反应堆切装备 32.89 fps。无边缘收束的优化中间版[日志](performance-final-runtime.txt)为 33.72／28.27／34.65 fps；**当前边缘版**同 Xorg/Mesa llvmpipe、1440×900、1×、四路各 25%、速度 1 的 8 秒[日志](performance-edge-runtime.txt)为不录制 33.48 fps（p50 29.11／p95 35.48 ms）、录制 27.88 fps（p50 34.88／p95 45.88 ms）、隐藏切装备 34.67 fps（p50 27.41／p95 35.49 ms）；[ffmpeg 日志](performance-edge-ffmpeg.txt)与[驱动](performance-final-driver.gd.txt)固定录制窗口。当前同环境可见／隐藏差约 1.19 fps，已非先前约 7.58 fps，但不同页面画面也变了，不能视作反应堆独占成本；录屏与游戏争用软件渲染 CPU。旧 00971 的 22.90→26.87／20.21→24.44 fps 仅是上一版短窗，不与本版混算。

[诊断日志](performance-diagnostic-runtime.txt)在优化前同实例测得全效果 25.65／恢复后 28.03 fps、只暂停相位写入 45.66 fps、等尺寸低成本材质但保相位写入 39.71 fps；后两项仅诊断，已撤销。可见窗内 `presentation_counts` 的 model／quote／preview／commands 均为 0、节点稳定 53、stage 绘制与静态场更新为 0、相位几乎每帧推进；所以**没有观察到隐藏页反复建控件或可见页高频报价／布局重建**，主要差异在动态材质像素工作与使其更新的相位写入，CPU/GPU 精确占比不能由 llvmpipe 分离。[同实例 ABAB 日志](performance-abab-runtime.txt)及[驱动](performance-abab-driver.gd.txt)在相同四路状态各 6 秒得原材质 27.80／27.94 fps、优化材质 33.44／33.92 fps。边缘收束加入前的短时固定相位[原材质](performance-original-phase.png)和[优化材质](performance-optimized-phase.png)，反应堆完整 `x=0…807,y=0…899` RGB 逐像素差为 0，证明工作效果计算优化自身无画面损失；当前版本刻意只改左右 24px 的最终收边，不能再声称与旧整图逐像素一致。右侧战场自主动画有差，未拿全屏差冒充 B01 差。目标硬件、最终跨页共享宿主、明确帧率门槛尚未提供／验证，故**不宣称最终性能通过**；目前仅能说此软件渲染环境内原约 10 fps 量级的可见／隐藏差已缩至约 1 fps。

| 绘制/布局边界 | 当前实际归属与接缝 |
|---|---|
| B01 内区 | `reactor_scene.gd` 根为 `808×900`、裁剪开启；`SubViewportContainer` 位于 `(0,65)`、尺寸 `808×835`。`reactor_stage.gd` 将整张不透明的 `1187×1326` 舱室加金属台底图绘到此内区；此版 `live-material.gdshader` 在原场景层内把左右约 24px 连同下台面端收向宿主深蓝，x0/x808 不再直接呈亮色断面。内部控件、均分、等级、费用和工作效果归 B01。 |
| 整体宿主 | 最新整体运行源 `zone_shell.gd` 绘顶轨 `y=0…65`（装备 `0…85`）、中间导航暗带 `x=808…855.875` 与 `x=808/854` 边线；战场投影 `x=855.875…1392.125`，最右保留 `47.875px`。`main.gd::_draw` 底色在不透明模块图后不可见。导航、资源、页面显隐、战场投影及公共边线归整体。 |
| 当前断点 | 最新整体 `design/clear-zone-host@f57e5e9fb46dc8184cf8dd2dc10a61b4750cffad` 的文稿明确原舞台层左右收边方向并保留公共导航；本组按此做了同层窄边候选，[四路整屏](controlled-four-active-1440x900.png)与[单路整屏](controlled-one-active-1440x900.png)已实看，但仍是在旧本地宿主下，**尚未在同版最新公共导航／装备材质组合里确认接缝**。需整体组固定运行 SHA、共享材质／边线与可交互净空后接此候选审整屏；本组再在原舞台层修具体接缝，不动已认可核心与设备主体、Owner、公共导航或战场。 |

| 用户退回项 | 本分支当前证据与未完范围 |
|---|---|
| 均分、等级升级区 | 受控 1／2／3／4 Owner 分配和按钮可见、四路报价／成交及 1× 整屏已有证据；最终共享宿主下的主次、边界与鼠标净空仍待统一组合实核，局部入框不等于用户验收。 |
| 1／2／3／4 模块 | 受控 1／2 的整实体、管、光、控件行、总段隐显和分配已覆盖；现行自然实现为 3／4，用户描述的单路自然关卡源表无门槛，遵其要求暂不改正式解锁。其他任意两模块组合没有单独绘制资产，当前受控双路专指武器＋炼铁。 |
| 性能 | 当前边缘版全效果同环境短窗从 25.31／21.08 提至 33.48／27.88 fps（无录／录屏），可见／隐藏环境差缩至约 1.19 fps；目标硬件与最终宿主未验收，不以诊断冻结态作产品。 |
| 跨页风格及左右边界 | 已在原舞台 shader 层把左右 24px 及下台端收向宿主深蓝；最新整体 f57e5e9f 仍为设计方向与旧宿主运行基线，没有接此源码的真实组合整屏，装备与反应堆异材质尚未通过。 |

以上是边界与证据交接，不是整体统一完成。共享宿主接同一运行提交后还需取装备／B01 完整整屏并审均分、升级与左右接缝；当前不合 main。
