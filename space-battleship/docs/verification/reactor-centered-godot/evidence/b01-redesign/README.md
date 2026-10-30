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
本入口对应 `implement/reactor-centered-godot` 从 `01efbf12e7c2d8a814343fe7503fd692861f4712` 延续的候选；原旧入口：../ship-hub-r9/README.md。本目录保留 `00971d36` 的原四路录像/早期性能与报价图作为历史对照；当前源码新增受控单／双路舱室、1／2／3 路无空槽控制井、八态原板建筑端部及同层左右收边；`936d2e4b` 在不改工作画面的前提下打包 mask 并跳过无效 active 采样，回放基线另由 `68f72e7a` 固定。原整体 Astra `b178ec39` 的十屏结论仅关闭当前端部**静态视觉**审，动态／鼠标链、性能目标及装备新版同版仍未关闭。下方“整屏统一与合法模块数交接”和末节列出当前源码的八态整屏、交互与性能证据；旧报价图仍只作历史对照；本节末已有当前 packed 版连续录像，但动态与最终组合仍待原审判定。

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

以上是边界与证据交接，不是整体统一完成。B01／公共壳同版候选已有整屏与短性能证据；装备新版尚无同版运行资产，接缝及跨页统一仍交整体原审，当前不合 main。

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

原整体 Astra 已按其固定 `b178ec39` 真组合十屏作**静态视觉**审：侧墙至台颊、公共导航与少态原生控件无明显遮断，可作为当前静态视觉阶段的候选，不再把“八态端部尚缺静态审”列作未完。该结论仅覆盖所审固定整屏；动态效果／鼠标链、最终性能、自然 1／2 开放和装备新版运行材质的跨页同版审仍独立待核。上段关于武器／盾球贴近边缘是交审观察，不表示静态阶段被退回；若后续审提出具体美术退点，本组按原舞台修源图。

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

[采集日志](shared-packed-continuous-after-pickup-ffmpeg.txt)和 ffprobe 核为 Xorg `:99`、Godot 4.7.2/OpenGL3/Mesa llvmpipe、ffmpeg x11grab／H.264 libx264 ultrafast CRF18／yuv420p、1440×900、25 fps、10.000 秒、250 帧、无音轨；新视频 SHA-256 `3e649abb4eabc8ea840e7a7da86553d4f89d6604624ccbe3c112553cc42c1e70`。已目视复看 0／4／8 秒整屏及每 0.25 秒全片接触表，完整解码全部 250 帧无错；进一步逐帧检查原提示覆盖区 `x250…489,y266…329` 的灰度均值：旧片最低 `73.42`（第 117 帧），新片最低 `177.03`（第 61 帧），没有旧片的遮暗突变。核心、四设备、导管和原生控制台在新片持续可见，战场继续推进。此证据供既有原审判断当前产品动态；不外推目标硬件帧率、升级操作或新版装备同版跨页通过。

### 给整体组的最小接入闭包

[integration-closure.json](integration-closure.json)把已测公共运行基线 `051cbd0d` 与本组 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 的**14 个模块差异文件**逐一固定 Git blob 与 SHA-256：八张 `1187×1326` 源板、`live-material.gdshader`、`reactor_stage.gd`、两张 packed mask 与对应 `.png.import`。`reactor_scene.gd` 在两树 Git 对象相同；原三 mask 保留未改，公共 `main/zone_shell` 不在此闭包。整体组可按清单只取这些模块文件接新装备运行树，再按原 `y65`、`808×835`、导航 `x808…855` 核真实同版画面及性能；不要把研究 SVG/静态 PNG 当运行材质。装备 `art/equipment-materials-main-20261029@4dd4f1238ad59517965409b58eb52fb3acb14438` 已有矩形卡、短／长机库和 Owner 运行 WIP，但其原入口明确仍是旧公共宿主、最后补丁只解析且正式共享组合未完成；故本清单不把 4dd 当成已审装备新运行输入。需要装备原组固定完整可运行 SHA、整体组接入并给真实 2／5／8 装备及 B01 同版整屏／性能后，本组按具体接缝退点继续。
