# Amount安全预览契约：固定来源与待审边界

**本页保留077cd522设计阶段的静态核对；后续运行候选状态/证据见[实现记录](amount-preview-implementation.md)，不把设计通过当运行验收。**

纯文档候选，分支`docs/amount-safe-preview-contract`；基底`372f8499b12b4efe88df22acff0554b147a3da38`。本次仅新增[14第9节](../game-design/14-ui-contracts.md#9-已审设计反应炉整组草稿与科研预算的amount安全预览)及入口；没有预览实现、游戏/配置变更或main发布。

## 请求与实际行为核对

- 请求固定：[83d6b47的R1表](https://github.com/rlmclmc2-boop/space_idle/blob/83d6b47ffe39e74a5d3307c222fde1651304b377/space-battleship/docs/ui-redesign-plan/g1-internal/g2-revision-r1.md)。其比例基准是总手动容量/近期收入；R1的逐项方案是此前可行路径，不是禁止必要模块入口的用户限制。最新候选已选择Reactor内整组金额入口，替代UI排序作为默认整组提交；原请求中的逐项回执行为不再作为新入口的规范。
- 最新前端还原资料固定：[5e287356的godot-restoration](https://github.com/rlmclmc2-boop/space_idle/blob/5e2873567c31eaa744c520485afaf605011303cd/space-battleship/docs/ui-redesign-plan/g1-internal/godot-restoration.md)，已读取R2单预算工作点及连续草稿同步补丁。两个模式分别记忆比例，本次精确金额与持续样本目标不互相覆盖；模式切换和点击已选模式均无提交副作用。
- 后端固定在`e93c221239a10d377b2ca89dd395ebcfa99c9819`；本任务此前已审候选未改Research/Reactor/Economy，当前基底同此行为。下表是实际源码边界，不把b7bb3de3的未合展示查询当主线已有接口。

| 来源 | 核对结果/拟复用 |
|---|---|
| `reactor.gd` `_capacity/_allocate/_distribute/_evaluate` | C先floor；单设备先保留其他已开放设备后钳到余额；均分配置顺序处理余数；免费充能不占手动容量，最终factor不能从占比分别猜。整组预览只对脱离所有者的目标求值；新具名命令一次验证/求值/接纳/发布，不经逐项_allocate钳制。 |
| `research.gd` `set_investment_text/set_investment` 114–129 | 原解析并floor；铁/铀分别变更/发investment_changed，不是两资源事务。 |
| `research.gd` `set_automatic/automatic_due` 131–145；`refresh_income` 225–278 | ratio仍受minimum_ratio限制；仅改开关/比例、不改当前金额、不重置refresh_elapsed。到期且实际岗位满足时按当次income样本max(1,floor(...))刷新。 |
| `research.gd` `_required_work` 176起、`advance` 298起；`game_session.gd` 488、753、881–896、1225起 | 所需量cache目前在state内；预览不能为读而写入可保存required_work。原推进按余额耗尽精确分段，缺钱仍做基础工作；外部速度因子还含人员/算法，不可只拿岗位bool代替速度。 |
| `economy.gd` `income_rates` 442–475 | investment按game字段，取(now−window,now]内合格已入账actual，含galaxy_yield，除完整窗口；peak是wall、production用production_base，三者不可混用。窗口自然移出样本也会改变收入，不能仅等钱包事件。 |
| `amount_value.hpp` ratio 173–177；`amount_api.hpp` div/to_ratio | ratio在被除数≥除数时直接返回1；不能拿该字段当资金能撑多少秒或研究ETA。普通div的Amount结果才是任意时长候选。 |

## 持续0%差异：只阻断该项现有能力宣称

已直接只读核对`config_excel/game_rules.xlsx`：`game_rules!A19=research_minimum_ratio`、`B19=0.001`，即0.1%=10基点。工作簿SHA256：`CA664A86FA325BB6A4767B5140067C27B32A08793188926AD6607A0614DC6791`。现有编译产物SHA256 `308B8F8089750DB99E0190526F2F1FDE91EE2950C5229567D295860B04D077DE`同值；未重编或改工作簿。

R1/R2把“持续0%至少1”写成现有行为，与当前setter的准入不符：开/关均会先因ratio<0.001拒绝。max(1,...)只是已合法进入周期求值后的下限，不能据它越过setter。候选保留原准入并输出InvalidResearchRatio；即时0%/手动0不受此限制。前端应修正当前可用性表述；若要把持续0%做成合法玩法，需要另获明确规则/配置变更授权，本提案不代选。此差异不阻断其他Amount预览契约的独立复审。

## 实施前的定向检查矩阵（尚未执行）

| 例子/边界 | 应有结果 |
|---|---|
| C=101，三项基点3333/3333/3334 | 比例目标33/33/33，剩2；不能擅把余数填满。equal按原规则为34/34/33，两种动作有别。 |
| 基点合计>10000、锁定/未知/漏项、目标Amount总和>C | 拒绝并保留草稿，不钳制/归一化。C=0、0%、任意大C不出现NaN或浮点金额。 |
| 当前武器45/防御35/熔炼20，确认整组60/35/5 | 所有者一次完整校验；普通拒绝保持提交时已接纳实际，不出现熔炼先变5的部分成功；成功一次接纳60/35/5并发布。 |
| 确认金额总100，容量变110/90或开放ID集合改变 | 110且集合不变时保留确认金额、余10，按新事实返回效果；90不可容纳或集合变化均拒绝，不钳制/补项/按比例重算。不需容量快照锁。 |
| 均分预览C101，提交时C102，三设备 | 一次distribute按提交时C102均分为34/34/34，不把预览34/34/33当作锁定金额。 |
| 收入10.9/3.2每游戏秒，3700bp，本次比例 | 目标4/1，净结余6.9/2.2；余额100/20时，断流且无其他支出的库存独撑25/20游戏秒。速率/时长Amount不经float。 |
| 当前样本无收入；本次0bp、合法持续10bp、持续0bp | 本次0/0；合法持续周期样本1/1；持续0不可提交。关闭自动沿用已接纳合法ratio，不清当前金额或周期相位。 |
| 钱包1e120、投入1e5每游戏秒 | 断流库存时长1e115游戏秒，不是to_ratio所得1秒；率0标not_spending/null，余额0且率>0为0秒。 |
| 钱包不足维持付费到完成、单资源先耗尽、率1 | speed_now只反映此快照；有条件完成估时独立求funded_speed，不能用缺钱时speed_now相除，明确足额资金假设/所需资金及当前覆盖性，不能充当实际ETA；缺钱基础工作继续，率1不伪称必有增速。 |
| 切模式/点已选模式、精确金额编辑后来源变化 | 保留两个本次金额草稿、各模式比例及当前生效值；本次主动滑动才重新生成金额。新来源下按保留金额重取比较，持续只重算样本预计值。 |
| 原刷新相位已过期但无岗位，之后恢复岗位 | 不能显示“开启后还要60秒”的固定倒计时；沿原due事实显示到期等待，原入口下次满足条件再刷新。 |
| 纯读、Research逐资源部分成功、容量/免费量/窗口自然过期/项目等级work变化 | 不支付/推进/prepare/保存；旧比较失效，成功回执优先；无全局revision框架，未变定义/所需量复用。 |

本次仅源码/请求/工作簿静态核对与Markdown链接、diff检查，没有运行新游戏测试或给“速度/估时实现通过”结论。三项只读候选的既有审核范围、其验证限制与main审批暂停保持原报告，不借本分支绕过发布门槛。

## 本次方案收敛（文档修订，尚未实施）

- Reactor整组意图选模块内最小具名**金额**入口：提交已显示/确认的完整canonical整数映射，一次校验/求值/接纳/发布。容量变但仍容纳时保留金额；容量不足或开放ID集合变更拒绝，不钳制或命令时重算基点。均分仍一次distribute，采用提交时状态。UI排序/部分成功不再是新整组默认方案。
- source只给外部必要容量、开放设备与当前/目标手动、免费、有效量及效果结果。内部容量输入因子、免费比例、人员/算法/peak由所有者管理，不交UI逐项比较失效；可见重读或模块必要通知即可，无容量快照锁。
- Research维持当前逐资源setter及独立set_automatic，不增加无消费者的批量入口。持续0%保留现行准入。有条件估时独立求持续足额资金假设的funded_speed；Session拟增最小公开research_preview_inputs提供外部速度，UI不读_research_speed。
- _capacity/_required_work写缓存已明确为纯预览的副作用边界：须提取无副作用部分或在含可写缓存的脱离数据上求值，不能对所有者真状态调用。独立审核本项无额外运行缺陷结论；此修订仍仅文档。

## 0d72b88d方案比较历史（非当前规范）

以下保留原候选比较，供追溯选择依据；其中UI先减后增、整组部分成功、比例命令、Research共同金额入口均不能据此直接实现。正式本次口径只以14第9节修订为准。


前端R1/R2已证明逐命令路径能表达操作意图，并未形成“不得新增必要模块入口”的用户限制。预览的Amount/单位与来源边界可先独立审；以下方案尚未选定，不能据本节直接实现或改动已有命令语义。

| 归属方案 | 所有者及可复用部分 | 复杂度、可见行为与风险 |
|---|---|---|
| Reactor现有逐设备路径 | UI保存整组草稿，排序先减后增，逐次allocate_text并重读实际；均分仍一次distribute | 运行改动最少，符合当前前端部分成功说明；UI却必须知道如何避免余额钳制、识别后续差异、首拒停止并处理每次发布。期间可出现中间分配/效果，publish_reactor原有防御/退却后果照常发生，不能由UI屏蔽。应评估这是否让整组调配业务反向落到UI。 |
| Reactor模块内具名整组入口（如apply_allocation_plan） | Reactor接收同一完整比例/金额意图及当下inputs，复用原解析/_capacity/分配/_evaluate与一次既有publish；普通拒绝不接纳候选，成功只accept一次 | 把整组预算、开放、取整及最终效果保持在所有者，UI不再排序或模拟中间业务，多次发布降为一次。需新增一个领域入口及对应接纳/错误验证，明确预览失效时不静默换目标；与当前逐命令的部分成功/中间效果不同，前端整组确认说明也须一致。沿原fault停机边界，不声称可回滚native故障，不建立跨模块事务框架。 |
| Research现有逐资源路径 | 比例换算/预览归Research；两个资源按钮各调set_investment_text，持续设置仍set_automatic | 符合R2分别应用/保留草稿，单资源编辑不需批量入口；共同预算的两项若分步应用，可能暂为新铁/旧铀，拒绝后各自保留真实结果，UI需说明。可复用不等于共同意图的最佳归属已定。 |
| Research模块内共同金额入口（如apply_investment_draft） | 只在确有“一次应用两资源”的动作时接收完整canonical金额，复用原解析/floor，先验证两项后由Research一次接纳/通知；单资源按钮继续原setter | Research没有本次即时钱包扣款或native发布，两项本地候选接纳可很小，不需通用事务。它可消除共同意图的混合中间设置；但若UI仍仅提供逐资源按钮，新增入口未必有实际消费者。不得把金额意图偷换成命令时重新按收入算比例，亦不因新入口替换旧单资源命令或持续规则。 |

双审须选择本次整组/共同意图的实际边界，并核对：所有权与UI认知负担、发布次数/中间状态、正常拒绝及既有fault、是否需要调整现有部分成功说明、具体动作是否有消费者。选择模块具名入口不等于扩成任意命令列表、全局回滚、跨模块批次或新玩法；选择顺序路径也须给出业务顺序留在UI的充分理由。当前保留两案，未先改接口实现。

以上“待选择/两案”的措辞仅属于0d72b88d历史；本次选择已见上节。

<a id="反应炉真实场景最小展示与局部通知提案待审未实施"></a>

## 反应炉真实场景最小展示与局部通知提案

本节是现有提案的定向续项，不回写前文077cd522阶段历史。设计`3d14ded8`已获根线程及反应炉原独审核限定通过；[运行实现候选与证据](reactor-presentation-implementation.md)待原双审、未合main。接口/字段与比例的唯一候选正文在[反应炉分册9.2.1](../game-design/contracts/reactor.md#921-实现候选真实展示与局部变化通知)；本节保留固定来源与已审实现方案，main继续暂停。取代本轮聊天中“现有信号+限频全量重读兜底”的初稿，不把旧轮询说成已审方案。

### 固定来源与已确认缺口

- 已审业务基线`09af963cf6f66146e019cecd08353426ab6d6abb`：Reactor已有allocation_plan_preview/apply_allocation_plan、_accepted_plan_readings/_plan_readings、_purchase/_quote及choices_changed；没有实际presentation_model/presentation_changed。反应炉原代码只接纳自己的候选，Scene不能读其私账。当前工作分支HEAD`5267f5f2`的相关Reactor/Economy主体沿此基线；M9新增不作为本项设计依赖。
- 实际消费者固定[8b78c8a的检查点](https://github.com/rlmclmc2-boop/space_idle/blob/8b78c8a84c62f3fd97df805c539bdcc8f950b69f/space-battleship/docs/verification/reactor-centered-godot/README.md)及同提交[src/ui/reactor_scene.gd](https://github.com/rlmclmc2-boop/space_idle/blob/8b78c8a84c62f3fd97df805c539bdcc8f950b69f/space-battleship/src/ui/reactor_scene.gd)，消费者Git blob为`20e31e3fe29224aee4efabf051f142ff5b34635d`。它已有bind_presentation(reader,context)、_dirty与当前模型驱动stage，但购级按钮从model.purchase_quote读取，预算变化若走_refresh会连带整场景和草稿重预览；被动_refresh还会按shares重新生成金额。这两处须做最小适配，不能拿夹具证明已接真实状态。
- 等级与当前供能/免费/效果已有实际源；_plan_readings只缺有限ratio/load/has_free。+1原_purchase已复用_quote并核level范围；新报价不调用purchase/payment。_evaluate中free=C×(state.free_charge+free_bonus)，是合法零容量、免费独立显示和饱和比例定义的来源，不新增公式或增长规则。

### 已审设计的最小实现落点

1. **当前展示**：新增Reactor.presentation_model()，从已接纳_state._capacity/_factors/_enabled构造最小脱离结果；不接收新capacity/free inputs来假装actual。_plan_readings增补比例助手，current/target及提交actual共用；按原AmountAPI比较/加法/to_ratio/to_display，不经float重建数量、不重新_evaluate实际状态。纯读不改_state/_prepared_state、随机、通知标记或RunState。
2. **报价分离**：新增Reactor.purchase_preview(can_pay)，固定+1，复用原_purchase(_state的脱离数据,1,false)及原范围/费用。成本与显示文本只按实际level及会话固定配置失效，可作脱离的模块内小缓存；预算变化只调用can_pay重验该原成本，不重新求幂/重新_quote。返回的缓存嵌套数据不能污染所有者；该展示缓存不进入save、候选接纳或价格真相，实际purchase始终重验。
3. **Reactor局部合并**：_adopt、成功restore_state、真正refresh_availability变化只标记deferred检查。比较的是最终公开实际事实（level、已接纳C/模块顺序/assigned/free/value及可用准入/读取就绪），不是全状态、输入因子、prepared或字符串显示。Amount只在合法源上用compare判等，表示差异不算实际变化。相同发布、prepare/discard/失败、同帧净回原状态均零通知。多个接纳合成一条changes；发送前更新基准并清queued，发送后不覆盖新重入状态。没有Session全局事件/全域revision/轮询兜底。
4. **真实预算变化**：Economy新增局部budget_changed(resource_ids)，在下面列出的真实_wallet写入完成点安排deferred比较；notify=false仅维持旧display_changed静默语义，不漏掉新预算事实。payment及验资不写余额；掉落移动/登记和收入窗口变化不得触发该新信号。临时持有首次写入前只读钱包、最终按已接纳_wallet核净差，资源列表脱离后发出，不复制第二份业务余额。
5. **宿主/消费者**：保留原owner/inputs/payment/publish注入。把presentation reader和quote reader分开绑定（可增加Scene.bind_purchase_quote(reader)），Scene增加独立quote dirty；原choices_changed→整场景invalidate连接改由新的presentation_changed承担，旧面板不变；presentation_changed仅使对应事实失效，level/availability才使+1成本/准入失效；budget_changed仅在实际+1成本resource IDs相交时使可支付性失效。quote dirty只刷新按钮/提示，不执行整场景_refresh、_preview_draft或stage快照上传。_command/command_finished不再成功后无条件invalidate，只处理消息、确认结果和清草稿；成功但实际未变可用已有actual model更新局部控件，不另读提供方。真正变化的标记由局部信号给出，不同步全读；与同帧deferred标记合并后下个可见帧各消费一次。隐藏停所有投影，重开一次新读；stage动画只用实际模型和宿主时钟，草稿不驱动负载。宿主context除game_time/paused外显式给running=公共RunState.is_running()，仅停机禁止业务交互，用户暂停仍沿原准入；不新增RunState广播或每帧模型读。沿既有金额草稿失效语义修正被动shares重算，不改均分或确认命令。

### 外部接纳/刷新路径清单（09af963c固定源码）

Reactor._adopt是正常接纳汇点；restore_state为重建例外，refresh_availability为开放准入事实。不得仅在UI命令成功回调通知而漏掉下列外部路径；也不在任一accept内部同步emit。deferred必须等本轮同步调用栈结束，包含外层世界/星球/船员/钱包及原通知交接完成后才读最终事实。

| 真实路径 | 现有准备/接纳落点 | 本提案如何覆盖 |
|---|---|---|
| purchase、allocate_text、distribute、refresh | Reactor._submit→Session.publish_reactor→reactor.accept→_adopt；Session继续更新_reactor_factors/收入/预算与必要退却 | _adopt仅排队，待完整publish/外层调用返回后比最终事实；失败只清prepared，不通知。原业务返回/旧choices顺序保持。 |
| 新整组金额提交 | apply_allocation_plan→publish_reactor→accept/_adopt，原方法成功后choices_changed | 同一deferred队列；不因为已有choices再重复立即读取。普通拒绝/无净变不发presentation_changed。 |
| 换舰/换装、无人机/挂设及其他配装成长发布 | _growth_setup→reactor.prepare；publish_equipment_refit在native成功、相关模块接纳后reactor.accept，再接纳预算/船型等 | _adopt涵盖；_growth_setup仅prepare、native拒绝/discard不触发。新信号不改变现有同步回调见到整批已接纳事实的边界。 |
| 外部世界容量/免费量变化 | publish_world→_publish_world_values按来源变化prepare，native值成功后reactor.accept；星球publish_planet_claim等外层还会接纳/发原模块通知 | 同一deferred排队，不在_publish_world_values内同步发送；外层普通失败丢候选/恢复来源，不靠通知伪造回滚。真正已接纳状态才参与最终比较。 |
| 进度开放/凝聚解锁 | 进度同步块refresh_availability(...,false)；modules_changed时refresh(...,publish_reactor.bind(false))；随后_notify_progress.publish_availability | 开放准入改变仅排队，接纳后的模块/效果与本轮最终准入共同比较。cache尚不匹配开放集时不可伪装已就绪快照。原choices不代替新实际状态通知。 |
| refresh_growth及自动岗位触发 | modules_changed→reactor.refresh→publish_reactor；购级自动路径也走purchase/_submit | 不新建旁路通知，同样由_adopt覆盖；自动路径实际不变不广播。 |
| 初始/恢复/重铸候选 | initialize的_growth_setup→battle.initialize_player→reactor.accept；_restore_modules→restore_state+refresh_availability(false)；prepare_reforge重建候选后publish_equipment_refit | 每个Reactor实例独立队列，未绑定候选不影响当前页面；换Session断旧连接/绑定新实例并一次初读。restore后缺_capacity/_enabled时保持未知，直到真实接纳，不调用prepare补缓存。 |

### Economy钱包写入与无关事件排除（09af963c固定源码）

| 钱包写入点 | 实际来源与时机 | +1可支付性的失效边界 |
|---|---|---|
| accept_budget(next,notify) | 原校验后接纳候选预算；Session付款/科研消耗/装备或反应炉购买、奖励/兑换等均经此口。notify=false在同步批次内使用 | 仅真余额净差，deferred到原批次完成；相同预算或本轮净回原值不触发。不要只监听publish_budget_change，避免漏掉静默接纳。 |
| collect_drop | 原Amount入账后，钱包、收入样本、掉落/标记删除完成为同一领取 | 新信号按真实资源净差；未领取的登记/掉落移动只有display_changed，不进入本信号。零增量或Amount精度使最终余额未变时不触发报价。 |
| credit_yield | 原quantity>0及Amount.add成功后接纳钱包，再更新样本；离线credit_offline也复用此口 | 最终该资源余额确变才通知；非+1成本资源不触发反应炉报价，收入历史本身不触发。 |
| restore_state | 完整校验后更换钱包及其他Economy状态 | 当前实例仅净变资源；会话替换另由宿主一次初读/重绑。恢复失败不得排队成功事件。 |

上述是当前四类_wallet赋值路径，不把notify flag、_balance_dirty、display_changed、drop_collected或整个save hash当作余额变化证据。用原Amount.compare把缺键和0视为同余额，不把只改表示的字典差异计为变化。只有临时通知基准，不新增持久化账本/事件回放。消费方预算回调只交集原报价公开costs.keys，不读取Reactor._parameters猜资源。

### 已审设计要求的验证矩阵

- 原current/target/actual文本、费用、均分、免费量/效果及确认结果与09af相同；展示读取前后_state/prepared/save不变，返回深改无污染。
- 合法C>0/A=0/F>0仍有真实负载；合法C=0按原公式F=0且E=0，比例0/效果1；缺缓存为未知，C=0/F>0不作合法夹具。极大Amount、有效量超过C时to_ratio有限饱和，canonical文本不被截断。
- 明确的prepare/discard/发布拒绝窗口零新通知；成功_adopt外部所有路径合并，监听者读到本轮完整事实；同帧多改一次、A→B→A零次、相同结果发布零次，回调重入不被旧快照覆盖。
- Economy四类真写入逐项核验，notify=false不漏、同预算/零增量/Amount表示差异/本轮净回原值不通知。仅移动/生成/登记掉落、收入窗口/显示刷新零报价失效；不相关资源真变也零反应炉报价更新。
- 预算只变时，场景model/preview/stage更新次数不增加，原成本_quote计算次数不增加，仅相关+1可支付性重验；实际level变化才重算价。隐藏期零投影，重开各初读一次；动画时钟不读取模型/报价；凝聚集合变更失效旧预览，未知禁用，来源变化保留canonical金额。

`3d14ded8`提交时只固定两份设计文档，未实施或运行测试；该历史不改写。后续运行候选及定向覆盖以独立实现记录为准，不把本矩阵全部当作消费者UI验收。原M10文稿WIP继续保持字节不变、不纳入本项；不改配置/native/保存/主线。
