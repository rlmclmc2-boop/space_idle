# 14 模块前后端连接契约

[回唯一入口](README.md)。本页统一列模块级状态读取、操作与结果、变化通知、前端本地状态和待补接口；玩法仍见01–04，数据/保存见06，纯前端布局、美术与资产接口见[13](13-art-interaction.md)。不新增全能中间层、通用DTO或消息总线，不以本页授权批量重写后端或改C4实现。

## 1. 版本与使用边界

| 标记 | 含义 |
|---|---|
| 主线现有 | 以 `main@08bf2e1e10d69a5edf2e94919ffc9357234129d9` 的源码核对，含已合入的C1容量消费修正。各分册第2节仅列此版本确有的端口/连接。 |
| 候选已实现、未合主线 | `rewrite/ui-review-followup@b7bb3de33287783721a8bbd9417f2ea040ad32ff` 中的展示扩展和反馈修正。只有C1已单独合入；其余不能当作主线现有能力或整体通过。各分册第3节显式列出。 |
| 待补/待审 | 已识别的交换数据或展示缺口，不表示端口已经存在，也不默认批准新增字段、规则或实现。先复用现有公开查询，再确认最小增补。 |

来源记录为[共用接口候选及验证边界](https://github.com/rlmclmc2-boop/space_idle/blob/fa1373dd13ca8b8e3eb12d928ede107191f96741/interface-candidate.md)及同提交的[交接说明](https://github.com/rlmclmc2-boop/space_idle/blob/fa1373dd13ca8b8e3eb12d928ede107191f96741/review.md)。候选中的受控回调/历史GPU画面不证明当前主线实操通过；不据历史窄屏证据启动适配或检查，本阶段范围服从入口的桌面宽屏要求。

后端拥有规则、费用、Amount、容量/解锁、进度、随机、候选接纳和真实状态。前端只读必要事实、提交稳定对象ID与候选输入、显示实际结果；跨模块动作走现有GameSession协调口或注入callable，普通模块动作保持所属模块直调。**读取查询、命令和消费事件必须区分，不能把所有返回Dictionary的方法当作只读查询。** 不由UI重复计算成长、报价、MAX、伤害、研究速度或任务推进。

## 2. 主线现有模块连接

以下文件名均指 `src/ui/<名称>.gd`；公开方法由对应 `src/systems/<模块>.gd` 或 `src/game_session.gd` 提供。结果解释及接纳顺序见第4–5节；不要求所有命令拥有同一组附加返回字段。

按模块只读所需分册；版本与第4–6节共同边界仍以本页为准。分册沿用原节号，“本页第N节”指本共同页或分册的同号正文；旧链接保留跳转，不保留正文副本。

| 模块 | 唯一模块契约正文 |
|---|---|
| 战斗/航程/拾取 | [战斗/航程/拾取](contracts/battle.md) |
| 舰体/装备 | [舰体/装备](contracts/equipment.md) |
| 反应炉 | [反应炉](contracts/reactor.md) |
| 科研 | [科研](contracts/research.md) |
| 强化 | [强化](contracts/enhancement.md) |
| 船员 | [船员](contracts/crew.md) |
| 星球 | [星球](contracts/planet.md) |
| 星系 | [星系](contracts/galaxy.md) |
| 超空间 | [超空间](contracts/hyperspace.md) |
| 档案/通知/设置 | [档案/通知/设置](contracts/persistence.md) |

## 3. 候选展示扩展与尚未补齐的交换

**各分册第3节“候选”均只在第1节指定的候选代码存在，未因文档收录而进入主线。** 新前端可据此评估接入依赖，不能直接调用不存在的主线方法，也不能以读取私有字段替代缺少的端口。

候选新增查询的最小字段截面按模块列在分册第3节，均为展示输出而非新增全量业务状态副本：

## 4. 查询、操作结果与单一消费事件

- 查询结果按只读消费；只把方法实际保证的副本/只读性作为保证，不推定所有Dictionary都深只读。显示缓存不能成为业务真相，不经float重建Amount；概率、坐标和秒数仍按现有类型处理。
- 命令传稳定ID与候选输入。普通拒绝保留可修正的草稿并显示领域reason；`message`可能由当前页面补充，不假定所有命令都有统一details、new_level或balance字段。成功后读取对应模块当前值、实际费用/余额和效果，不以动画或控件变化冒充提交成功。
- 跨模块接纳遵守第5节。保存请求的 `ok`/generation只代表请求已接受或排队，不自动等于磁盘完成；失败、busy和持久完成继续读取SaveFiles状态。
- 危险预览要持续到确认、取消或失效。对象/来源/输入改变后不能确认旧预览；重复确认保留原幂等保护，不重新扣费。预览、前后对照与实际余额应绑定同一对象身份。
- **`Battle.consume_damage_receipts()`不是只读查询。** 它在 `src/systems/battle.gd:215–218` 从_events提取kind=8并移除。当前唯一调用者是 `BattleView._process`（`src/ui/battle_view.gd:25`），由它一次消费、生成伤害数字并发出既有damage_received音效信号。HUD、统计、其他页面和调试观察者不得再次调用，避免先取走/吞事件；它们使用hud_values/statistics/attribute_details等独立查询。
- 伤害回执是帧内表现事件，可受显示预算限制，不是完整持久伤害账本，也不能据此结算奖励。若未来需要复用同批表现信息，由单一消费方在消费后提供局部只读副本，不各自drain；不为此新增业务广播链。宿主/native的业务结果仍由既有单一业务入口接纳。
- 变化通知只使相关对象/选项失效，在可见显示帧合并读取。隐藏的局部舞台停止无用刷新，但业务时间/任务不因页面隐藏而停下；缺少通知的模块如仍轮询，必须明确为现行事实，不能冒充已具备信号契约。

## 5. 既有跨模块接纳与通知约束

下列内容自05的“现行模块交接契约”移至本页集中维护；属于原有接纳约束，不是本次新增统一协议或每条实现已完成实操验收的声明。此表是后端所有者之间的协调协议，不是前端可直接调用的接纳清单；UI仍从第2节的动作或注入callable进入，不调用accept_*或native提交口绕过协调。

**既有分工约束：** 模块前后端仅通过必要的领域状态、具名操作、操作结果及变化通知交接；后端负责规则与真实状态，前端据此独立设计布局、美术与控件。画布、安装框、锚点、贴图和效果等纯表现元数据属于前端资源契约，不混入业务协议；确有命中用途的共享几何仍按既有native契约处理。具体主线端口与候选状态见本页第2–3节，不增设另一套通用协议。

模块化的边界是业务入口和结果，不是信号连接顺序。模块只能拥有自己的候选与已接纳状态；`GameSession` 只协调具名端口，不读取候选内部字段来决定下一步，也不以 UI 通知承担接纳。入口返回 `ok=true` 表示本次业务交接已完成；`ok=false` 且 `fault` 不为真表示普通拒绝，当前子命令的所有者保持原状态。批量购买可能先接纳已成交子项，再返回后续子项的拒绝，已成交部分不回滚。native 或几何在提交中发生致命故障时 RunState 停机，不假装已回滚。通知只在所有受影响所有者完成接纳后发出；监听者同步读取应得到同一批状态。发出通知后，外层调用不得再写回该批的旧候选，以免覆盖监听者的重入操作。

| 所有者 / 入口与输入 | 输出与成功含义 | 状态、拒绝、故障和通知 |
| --- | --- | --- |
| Equipment `equip_slot`、`buy_all_levels`、`resize_mounts`：部位/选择、当前装配事实、报价与支付、`publish_equipment_refit` 或 `publish_equipment_levels` | `ok` 表示 native 接受且装备候选、钱包、船型/必要撤退已接纳；批量购买允许已成交部分保留，空批次返回 `NoChange` | Equipment 独占槽位候选和槽位账本；Session 调用 `accept_prepared`，再发布 `slots_changed`/`loadout_changed`。普通报价、支付或 native 拒绝丢弃候选；致命故障停机。防御换型按[03第1.4节HealthAdjustment](03-progression.md#14-容量改变时的生命规则)保留同类总当前/总最大比例并重建模块损伤；未决仅为[03第1节首槽换型](03-progression.md#1-舰体槽位与升级)本身使两类当前余量均为0时是否立即进入死亡判定。 |
| Enhancement `purchase`、`set_order`、`set_branch`：可用性/装甲数、报价、native 发布口 | `ok` 表示强化状态、native 值及钱包/必要撤退全部接纳；无变化跳过 | Enhancement 独占强化候选，经 Session 的 `publish_enhancement` 后显式 `accept_prepared`；不发业务接纳信号。拒绝不写强化或钱包，致命 native 故障停机。 |
| Reactor `purchase`、`allocate_text`、`distribute`、`refresh`：容量、开放模块、支付与 native 发布口 | `ok` 表示分配状态、native 值及钱包/必要撤退已接纳 | Reactor 独占 `_prepared_state`；Session 调用 `accept` 后更新贡献和钱包。普通拒绝丢弃候选；致命故障停机。`choices_changed` 仅作接纳后的 UI 提醒。 |
| Planet `claim_build`：建筑、贡献发布口 | `ok` 表示建筑、世界贡献、native 和必要撤退均已接纳 | Planet 独占建筑候选；Session 通过 `accept_prepared_claim` 显式接纳，再发建筑/开放通知。普通拒绝不改变建筑或世界贡献；故障停机。 |
| Campaign `advance`、`observe_battle`：固定步长、native 战斗结果、终波领取口 | 返回位置变化事实；清关和新关事实在完整关卡位置/战点更新后可见 | Campaign 独占关卡、波次、驻守和撤退。`take_progress_changed` 交给 Session 同步 Research、Reactor、Equipment、Crew、Planet、Galaxy 的开放缓存和必要贡献；之后才发布进度与状态通知。终波收取先批量接纳，随后统一通知。普通关卡拒绝不推进；native/几何故障停机。 |
| Economy `payment`、`accept_budget`、`collect_due`：费用、候选钱包、拾取时间和收益因子 | 支付只返回候选钱包；`accept_budget` 后才归属变更；批量领取返回 `collected` | Economy 独占余额、掉落和收入历史。通知可延至跨模块接纳后；终波多个掉落合并通知。拒绝不扣款或领取；已领取后续致命故障停机，不虚构回滚。 |
| Battle `commit_player`、`commit_values`、`advance`：准备好的战斗描述与变更种类 | native 接受后返回 `ok`/`defence_changed`；结果只含已发生的战斗事实 | Battle/native 独占战斗状态与攻击出生快照；普通拒绝不接纳外部候选，`fault` 触发 RunState 停机。Session 只根据公开结果完成其他所有者接纳。 |
| Research `refresh_progress`/`advance`、Crew `refresh_availability`/`contributions`、Galaxy `refresh_availability`/`contributions`：Campaign 开放查询或时间/分配事实 | 返回开放变化或贡献；成功后由所属模块持有状态 | 各模块独占自己的开放缓存与进度。Session 先同步相关缓存及贡献，再调用独立 UI 通知端口；不以模块私有字段或消费者刷新顺序作为契约。普通拒绝保持归属状态，推进中故障停机。 |

一次命令的时序为：模块校验并保留候选 → Economy 给出候选钱包 → Session 组装并提交 Battle/native → 所属模块显式接纳 → Session 接纳钱包、世界/研究/反应炉贡献、船型与必要撤退 → 发布各模块展示通知。没有效果的命令跳过提交；部分批量成交只提交已成交部分。通知可同步重入，新命令必须看到上一批完整状态，上一批外层调用此后不再改写它。

终波的 native 掉落登记与强制领取先静默进入 Economy；Campaign 完成清关事实，Session 同步开放缓存，再按本步最终收入刷新贡献，最后合并发布掉落/余额、开放和进度通知。非终波新掉落也在该步 Campaign 处理完成后通知。致命 native 或几何提交故障的公开结果保留 `fault=true`，供调用者区别于普通拒绝。

## 6. 前端本地状态与资产接口

选择、草稿、焦点、展开、滚动、pan/zoom、显示变换、临时反馈与待确认UI记录属于前端；已付等级、钱包、实际占用、进度、随机、有效贡献与保存事实归后端。前端本地状态不能回写为领域状态，刷新不得覆盖未提交草稿；对象失效时清除旧详情并阻止向旧ID提交。

模块状态先映射为设备身份、运行/停机、进度、选中等前端显示输入，再由美术和控件消费。画布、可见边界、底座/管口锚点、允许裁切区、点击区、文字安全区、图层与导出约定只在[13全局规范及相应M/V](13-art-interaction.md#3-按模块读取设计与验收)定义；不把资产坐标加入经济/研究/分配领域对象，不将金额或进度烘焙进图。真正参与命中的共享几何继续使用既有native契约。

资产、布局与业务可以分别迭代，但以相同稳定对象ID和公开端口连接。需要新交换数据时先确认所属模块已有端口及最小缺口；不以本页的新设计表述自动授权后台、递归/父身份、保存格式或玩法变更。C4仍以裁定清单的只读审核/待定状态处理。

### 6.1 共享宿主的最小呈现交接（设计期）

**后续运行状态更新：** 用户已要求继续授权的公共UI与业务接入；下述原设计记录的“未实现/不改代码”仅指当时状态。当前候选的具体已实现端口和未覆盖范围见6.4，不升级为主线事实。

本节与[13§2.4](13-art-interaction.md#24-共享宿主与模块安装约定设计期)共同供各模块引用。整体线程负责所有模块的共享交接和顶部入口；本节不声明新增生命周期方法已实现，不改第2–5节领域契约。区域数字和图稿是待确认候选，确认前不改运行代码。H1重分区已被根审阻断并撤回，本节不授权656宽适配或统一新安全内区；宿主先核已有模块画布和顶部边界，比例改变须另交净收益/可读性证据。

| 时点 / 所属 | 最小交接与行为 |
|---|---|
| 注册 / 宿主 | 使用稳定module_id、中文入口名、内容Control和下表逐项列出的公开开放判断。当前基线为`main.gd::_register_left_module(layer,id,title,scene,unlock_kind,unlock_target)`；本轮只据其事实设计后续扩展，现有参数不能冒充已支持新区域协议。前端装配说明单列画布/安全区/背景归属，不混入领域Dictionary。 |
| 数据绑定 / 模块 | 沿用该模块公开只读查询、具名操作、注入callable及变化信号。缺口由所属方确认最小增补；宿主不读私有缓存、不计算Amount/报价/MAX/效果、不代发原生接纳。 |
| 挂载 / 宿主与模块 | 宿主创建或接入一次内容实例并给出安装矩形、裁切边界、层级与指针范围；模块建立自己的实际必要订阅。内容准备完成后才显示，不用重建全体模块刷新单页；不把挂载当成领域命令。 |
| 激活/隐藏 / 宿主与模块 | 宿主只选一个模块显示，统一当前入口/焦点。区域改变、激活/隐藏、释放是必要的局部呈现通知：优先复用现有Control尺寸/visibility生命周期；确需具名调用时由双方固定实际签名，不假设已有通用activate/unmount方法，不广播给无关模块。模块保持选择、草稿、滚动、pan/zoom，合并局部失效；隐藏停止无用绘制/动画，重开读取当前状态且不追播离页时段。不得因hidden自动暂停业务、提交草稿或清空工作区。对象/开放集合失效仍由原契约处理。切换/收起前执行下述自有弹层与键盘门控约定，不能只在卸载时处理。 |
| 卸载 / 宿主与模块 | 仅在实际会话替换/退出或明确释放内容时进行；先阻止旧内容输入、移走焦点及弹层，再由持有者解除自己建立的信号/callable/节点引用，最后释放内容。旧Session结果不得写入新实例；日常切换只隐藏，不卸载或重建Session。 |
| 必要通知 / 各所有者 | 开放判断按下表逐模块保留各自公开来源，不能全部改为Campaign.available；余额消费Economy公开余额与现有display_changed/budget_changed的实际范围；保存沿既有poll/真实完成状态；模块对象变化仍由模块现有信号及可见帧合并读取处理。没有通知的模块保留原明确轮询，不以宿主新增全局刷新或广播总线。 |
| 模块动作结果 / 模块 | 成功/失败由动作所属视图解释并留在对应对象上下文，必要的宿主通用故障沿原入口显示。宿主不将所有返回Dictionary统一解释，不替模块保留/接纳领域候选。 |
| 输入与战场 / 宿主 | 顶部梁/导航/弹层先消费点击，遮罩防穿透；模块只收自身区域输入。鼠标遮罩不能代替下述Space/G键盘门控，main与逻辑战场两个入口必须一致拒绝UI占用时的全局快捷动作。战场统一映射完整表现与拾取，逻辑572×960和共享几何不因宿主适配变化；SubViewportContainer已有映射路径不能再重复逆变换。伤害回执仍仅BattleView单一消费，宿主不drain。 |

**公开开放来源（运行代码核对基线e77，`main.gd::_refresh_feature_visibility`）：** 下表保留原规则；通知列为接入所需的局部失效来源，不声明当前主入口已订阅全部这些信号。公开查询只判断入口，不在宿主复算解锁。

| 顶部入口 / 内容 | 必须保留的公开判断 | 所属通知/实际边界 |
|---|---|---|
| 装备 | 原默认可用入口，不新增Campaign门槛 | 原装备公开变化仍归装备视图。 |
| 反应炉 | `campaign_system.available("feature","reactor")` | Campaign `progress_changed`；仅这一类配置键可复用现有kind/target注册参数。 |
| 科研 | 遍历`research.choices().values()`，存在任一true | Research `choices_changed`；不能替换成某个feature键。 |
| 强化 | `campaign_system.available("feature","jewels")` | Campaign `progress_changed`。 |
| 船员 | `not crew_system.member_options().is_empty()` | Crew `options_changed`及实际选项失效；不按Campaign虚拟键代替成员事实。 |
| 星球 / 重铸入口 | `not planet_system.planet_options().is_empty()` | Planet `availability_changed`及实际选项失效；重铸的具体预览/准入仍走原事务。 |
| 星系 | `not galaxy_system.status_rows().is_empty()` | Galaxy `availability_changed/status_changed`的实际变化；不把status_rows为空猜成某关卡门槛。 |
| 超空间 | `hyperspace_system.unlocked(int(campaign_system.progress_facts().highest_reached))` | 当前没有专用领域变化信号，沿既有进度事实失效时查询，不伪造新信号。 |
| 舰船/航程/属性/档案/通知/设置 | 原常驻页入口；页内选项和命令保留所属准入 | 不通过统一Campaign.available封装改写原可达性。 |

**切换、收起与键盘输入的呈现交接（待实现）：**

| 状态 / 事件 | 弹层与焦点责任 | Space/G与导航结果 |
|---|---|---|
| 更多菜单、资源详情菜单或普通临时弹出控件打开 | 创建者拥有引用和关闭责任；宿主拥有其更多/全局资源菜单。点菜单外的首击只关闭并消费，不穿透拾取；菜单项选择后关闭菜单，再显现目标内容。 | 弹出期间阻断Space/G全局动作；菜单按自身既有键盘能力处理。关闭后焦点回可见的触发入口。 |
| 普通模块切换/收起 | 所属模块先隐藏/关闭自有非模态Popup/Window、悬停和浮层，保留普通详情选择；隐藏输入框/控件释放焦点。宿主关闭自有非模态浮层，将焦点移到可见当前/恢复入口，再隐藏内容。独立Window不能仅依赖父Control.hide。 | 此过程不提交/还原草稿。模块有实际键盘焦点时Space/G属于UI，不触发暂停/驻守；不能假设鼠标mask能屏蔽键盘。 |
| 危险确认、系统文件选择器或所属模块模态尚打开 | 创建者保留模态/事务上下文；顶部切换/收起暂时阻断并提示先完成或取消，不把隐藏当取消。宿主自有重铸/导入/新游戏待确认UI由宿主负责；模块自有模态由模块提供只读UI占用事实。 | 阻断Space/G全局动作；不隐式确认、取消或另增暂停规则。确认/取消后的领域语义沿原契约。 |
| 输入编辑、IME组合、按钮/滑杆/列表等UI键盘焦点 | 焦点控件照常处理其输入，所属视图负责报告UI占用。重新显示时焦点先回可见入口，不将焦点自动投给上次隐藏编辑框。点击战场且无模态/菜单时才退出UI焦点占用。 | Space/G不路由到全局动作；控件可按现有语义消费，不新增快捷键。 |
| 会话替换/实际卸载 | 按所有权先隐藏或关闭自有弹层、撤离焦点、断开旧UI占用通知，再释放内容；来源身份失效的旧模态不再可提交。 | 旧回调不能恢复快捷键或操作新Session。 |

门控是前端职责，不是新业务计算中心：宿主管主视口焦点/自有弹层，并接活动模块对其自有模态/编辑状态的最小只读UI占用通知；不扫描模块私有字段、不在后端保存UI状态。**当前`main.gd::_unhandled_input`的Space与`campaign_view.gd::_unhandled_input`的G没有这套共同门控**；后续授权实现时须让两者读取同一当前UI占用条件，且在向SubViewport转交键盘输入前阻断，不能只改root而漏逻辑视口。具体局部callable/通知签名需随接入提交固定，不在此虚称已有API。

**战场/HUD归属（H2最小方案）：**

| 显示项 | H2呈现所有者与坐标系 | 是否迁宿主 |
|---|---|---|
| 舰船/武器/弹体/接触/敌方血条/伤害数字/掉落 | 原BattleView/native表现及EconomyView，逻辑572×960视口；原完整映射保持 | 不迁；BattleView仍单一消费伤害回执，EconomyView沿原拾取输入。 |
| 盾甲双条 | `battle_hud.gd`的`DEFENCE_RECT=(12,708,548,122)`，原逻辑视口与0.9375显示比例 | 不迁，不延展到632容器或808模块，也不另绘一套宿主盾甲。 |
| 航程状态 | `campaign_view.gd`的逻辑(18,28)，原Campaign.status_text/status_changed | 不迁；G只新增上述前端输入门控，驻守业务仍归Campaign。 |
| 战斗即时统计短行 | `battle_hud.gd::STATISTICS_RECT=(12,902,548,25)`，消费现有`battle.statistics().display_text()` | 不迁，不因删除钱包框自行挪动/拉宽。 |
| 全局钱包 | 原`battle_hud.gd::RESOURCES_RECT`及装备标题中的重复全局余额，统一移至左顶部共享资源行 | 只迁余额呈现；仍读Economy.balance_rows，使用既有金额文本。模块费用/预算/局部报价保留。 |
| 暂停入口 | main创建，但仍挂原逻辑视口overlay，原(420,18) | 不迁，不再加顶梁第二个暂停按钮；行为仍走Session用户暂停口。 |
| 旧常驻教学提示 | “空格暂停 / G驻守 / 点击掉落领取”等旧HUD说明，不属于本轮认可的常驻公共读数 | 新宿主呈现移除这类常驻教学文案；快捷键、拾取功能及战斗逻辑保留，按13将教学/帮助与必要当前反馈分开。 |
| 保存/会话故障提示 | main原`_save_warning`，提案移左顶部共享状态位；短明确警示可点开完整说明 | 只迁通用提示；原poll/完成/失败事实不变，长故障信息不能静默省略。 |
| 属性详情、敌情/分来源统计、通知档案 | 左侧更多内的`attributes_panel`、`archive_panel`、`notifications_panel` | 原左侧只读内容重新挂到具名入口；不是把BattleHUD搬出逻辑视口，也不新增伤害消费。 |

装备组已交[9fc8e8df最小安装说明](https://github.com/rlmclmc2-boop/space_idle/blob/9fc8e8df4d2df74abf5357c28ecfaea9e458367c/space-battleship/docs/ui-redesign-plan/g1-internal/equipment-image-design/module-installation.md)：仅确认原808×900现状，不批准65px。原品牌/钱包/全局副标题可分离，但尚无安装开关；局部舰名、全部装备升级、费用/比较、底反馈必须保留。批量遮挡在CanvasLayer9的z19..21，不能拦住Layer10导航；后续UI占用交接须让宿主门控顶部入口、Space/G及战场输入，而不是把一个更高层全屏遮罩盖住批量控件。模块保留批量内容/回执/报价和本层遮挡，宿主只统筹跨层输入；该通知与焦点处理尚未实现。其余原组书面确认由根线程协调，不从当前设计预览推导全部可装入。

更多菜单到实际内容根的唯一映射及普通/更多/收起状态示意见[共享宿主方案](../ui-redesign-plan/shared-host-shell/README.md#入口到现有内容的映射)。此前H1生成图的HUD范围不符合本表，已撤回，不能据图扩展实际HUD。

模块组每次Git交接列：固定commit、内容根路径、所属公开绑定、13要求的安装说明、实际订阅/释放责任和同版整屏证据；注明自然状态/临时开放/预算注入。宿主线程核边界与公共入口，原组继续负责内部品质和业务绑定。截图、布局分析和文档不证明运行、动态或V0通过；待用户确认设计后实施，仍不合main。

### 6.2 H2三组安装收口与最小视图协作（职责/端口限定通过，未实现）

三组书面现状已齐：装备9fc8e8df、反应炉0e0c02f7、星球2208b369。它们确认现有808×900，不批准65px或更小安装；具体固定来源、矩形及协作收口见[H2安装候选](../ui-redesign-plan/shared-host-shell/installation-resolution.md)。ac8a4d54的安装职责及四个最小视图端口已获原双审限定通过；此处仍是宿主前端边界，不升级实施审批。

候选用首行原96px品牌位承载活动上下文：反应炉原组用已有模块身份与等级提供“反应炉2级”式简洁对象＋等级读数，不新增数据或大标题，星球“星球探索”身份由原组提供，装备默认品牌；身份/等级不再落左侧空带，不改设备/首行操作/主控/底反馈坐标。装备分离全局副标题后保留y65..85背景，星球分离静态标题后保留y65..90背景，不裁或下移内容根。背景仅在各组声明的纯环境区域使用共享背板，最终接缝品质仍须整屏视觉审。

拟新增的视图端口仅为`set_shared_host(enabled, context_slot, backdrop)`、`has_exclusive_ui()`、`exclusive_ui_changed`和`prepare_host_hide(force=false)`；语义、实际签名、上下文Control释放顺序见上述候选。它们均为Control/纹理/显隐/输入的本地协作，不是领域DTO或命令路由；当前并未实现。宿主注册的可用性callable仍逐项读6.1原公开判定。Layer9模块自有批量由模块保留，宿主只阻断顶部与战场输入区，不以高层全屏遮罩盖死其控件；Space/G条件共享但业务不搬入宿主。

### 6.3 反应炉新稿制作坐标收口（不改业务/端口）

7fcefeb9的侧带填空被用户否决，旧背板不通过。用户要求原反应炉组重出图；制作边界按[13§2.5](13-art-interaction.md#25-反应炉重出图的当前固定制作范围-v1)及[作图范围V1](../ui-redesign-plan/shared-host-shell/reactor-drawing-v1/README.md)固定。模块外根仍808×900，新增稿内容根(0,65)/808×835；内容到宿主只平移(0,65)，所有新图/效果/读控/点击元数据统一以内容本地为原点。旧纵板及其显示锚点不作为新稿约束；原组重新组织有效展示包络，不由宿主填两侧。

现有稳定功能ID、领域读取/报价/操作/结果、时间与分配接纳语义保持。6.2四个最小视图端口/安装职责的限定通过保持；可选`backdrop`签名不重开，但新反应炉默认不消费旧侧带背板，不把该参数当填空路径。其他模块安装现状不因本次新画板改变；战场投影/输入/单一事件消费完全不动。

## 7. 已实现出口：敌盾与双条的最小战场展示契约

正文移至[战斗/航程/拾取分册](contracts/battle.md#7-已实现出口敌盾与双条的最小战场展示契约)。
### 7.1 实现前基线与已实现出口

正文移至[战斗/航程/拾取分册](contracts/battle.md#71-实现前基线与已实现出口)。
### 7.2 身份、快照与失效

正文移至[战斗/航程/拾取分册](contracts/battle.md#72-身份快照与失效)。
### 7.3 隔离、Amount与绑定边界

正文移至[战斗/航程/拾取分册](contracts/battle.md#73-隔离amount与绑定边界)。

## 8. 已审待实施：成员、设施与选中节点的最小只读事实

**状态：已审待实施；不作为主线已有方法。** 本节只约定当前成员、当前设施和当前节点事实。审查依据与未覆盖项另见[核对记录](../verification/frontend-contract-audit/colony-readonly-proposal.md)。比例/预算意图、整组原子调配、动态战斗效果和未来效果预测不在本节范围。

### 8.1 共同读取与身份边界

- 方法仅投影已接纳事实和必要的只读缓存；不调用推进、派遣、领取、接纳、支付、RNG或保存，不借读取新增RunState故障/重复领域校验职责。候选或命令完成后才可见的字段不得提前冒充实际值。
- 对外数组、行及嵌套数组/字典均为脱离所有者的快照或递归只读值。Amount以既有规范文本输出，显示比例为有限float且仅用于绘制；不经float重建Amount、经验门槛、贡献或费用。没有适用值用下文约定的null/空字段，不以0伪装未知。
- Crew成员id沿用配置String；设施身份是`(planet_id, id)`，planet_id沿用主线的规范十进制String、id沿用实际设施定义键；节点身份是`(region_id, id)`，id为当前公开region.nodes的String键。不得使用显示名、列表位置或演示中的1–30编号替换实际键，也不新增跨模块通用ID编码。
- 会话替换/恢复或模型重建后，装配处清除旧选择绑定与缓存；不存在/不可见对象从当前结果消失时，前端清除旧详情并停止向旧对象发命令。本节不增加保存字段或承诺跨会话展示缓存连续。
- 保留`Planet.visual_snapshot`的星体/探索时钟、`Galaxy.visual_snapshot`的地图/父连接、`Crew.galaxy_assignments`的区域人数及现有准入接口。位置、头像映射、模型family、设施屏幕锚点、控件草稿和视角属于前端资源/本地状态，不进入本节输出。

### 8.2 Crew：成员事实

正文移至[船员分册](contracts/crew.md#82-crew成员事实)。

### 8.3 Planet：设施事实

正文移至[星球分册](contracts/planet.md#83-planet设施事实)。

### 8.4 Galaxy：选中节点事实

正文移至[星系分册](contracts/galaxy.md#84-galaxy选中节点事实)。

### 8.5 失效通知与独立落地边界

- 三项均在可见显示帧合并失效读取；隐藏视图停止无用投影，业务照常推进，重开读最新完整事实。Amount文本、经验门槛、静态设施/节点定义与未变快照只随对应事实变化重建；不因窗口尺寸或显示帧反复求幂/求值。
- 每项可单独评审/实现；依赖的人员输入复用已有只读视图，不增加相互持有的模块对象或新业务协调。未选定的比例/预算、整组原子提交、未来效果/动态战斗效果继续待定，不能以本节授权运行实现或整批G2验收。
## 9. 已审设计：反应炉整组草稿与科研预算的Amount安全预览

**状态：设计已审；[运行实现候选](../verification/amount-preview-implementation.md)未合主线、待双审，不作为主线已有方法。** 只补当前已定工作点需要的只读换算/比较；玩法及接纳仍按[03第2–3节](03-progression.md#2-反应炉)和本页第5节。固定请求、源码核对及持续0%的差异见[审查记录](../verification/amount-safe-preview-contract.md)。本节选定Reactor最小具名整组金额入口及Research原单资源入口的归属；不引入通用事务层、保存字段、随机现金流预测或未选UI。

### 9.1 单位与共同读取边界

- 比例输入为整数基点`0..10000`，10000表示100%。Amount金额、容量、速率、工程量、倍率及任意时长以原规范文本输出；业务复用原Amount求值。比例先在Amount域除10000，再乘基准并floor，不能先把大额转float/Number/BigInt或用控件位置重算。有限float只用于基点控件/进度条，不重建数量。
- 预览只读已接纳状态与同一次同步新读的来源；不调用命令、prepare/accept、推进、扣款、抽样或保存，不制造RunState故障。现行_capacity会写容量缓存，_required_work会写required_work；纯预览不得直接对所有者真状态调用它们。须提取无副作用求值或在脱离所有者的数据（含会写入的嵌套缓存）上求值，不借读取填写业务字段/缓存。返回行及嵌套数据均脱离所有者或递归只读。
- 结果分开`current`（已接纳）、`target`（本草稿条件下）、`source`（外部必要的公开结果事实）；`can_apply/reason`只说明本次检查，不承诺下一次提交必成。未知值用null及具体原因，不补0/×1。Amount短文本由提供方格式化，canonical全文保留用于精确提交；UI不从短文本还原值。
- 净收入不向非负Amount塞负数：用`direction=surplus/deficit/balanced`与非负`amount`文本表示差额。持续时间用Amount的`div`求游戏秒，可供提供方格式化；`to_ratio`被限制在[0,1]，仅能作显示比例或既有有界分段系数，不能作为秒数。

### 9.2 Reactor：整组分配预览

正文移至[反应炉分册](contracts/reactor.md#92-reactor整组分配预览)。

### 9.3 Research：单工作点预算预览

正文移至[科研分册](contracts/research.md#93-research单工作点预算预览)。

### 9.4 草稿、来源变化与失效

本次/持续是前端局部工作模式，分别记忆比例草稿，共用一个可见控件；点击已选模式/切模式不提交、不覆盖两个本次金额草稿或已生效设置。持续模式只更新自己的比例及样本预计值。主动拖动本次比例才重生成金额；被动来源刷新或切模式保留已生成/精确编辑的canonical金额，按once_amounts重取比较。Reactor已显示的canonical金额目标保留；容量/开放/效果来源变化时，按amounts重读可容纳性与效果，不被动按原比例改金额。主动修改比例才重新生成目标。确认后仍提交该金额映射，不保留旧容量的效果结论。

影响容量、免费量、开放模块、已接纳分配或科研钱包/窗口/项目/work/投入/周期/速度/效果的变化，由相应所有者管理预览失效或在可见时重读。对UI只给容量、开放设备、当前/目标业务读数及必要研究状态；不公开容量输入因子、人员/算法/peak等内部组成让UI比较。无需全局revision/fingerprint或容量快照锁；命令按当前事实校验所确认的金额，成功实际回执替换旧效果。

现有choices_changed/investment_changed、Economy显示变化、Crew成员/选项及实际贡献提供方事实可使读模型失效；它们不能冒称已覆盖所有时钟/收入窗口/研究进度与容量变化。实施时只在所有者补必要覆盖或在可见显示帧重读时钟相关事实，隐藏停无用投影、重开取最新；不读私有账本，不新增Session全局通知层。静态定义、所需工程量与未变效果按其真实来源复用，不因滑杆拖动/窗口尺寸反复求幂。

## 10. 实现候选：超空间只读预览与星球自动设置

模块正文见[超空间分册](contracts/hyperspace.md#10-实现候选超空间只读预览与星球自动设置)与[星球分册](contracts/planet.md#10-实现候选超空间只读预览与星球自动设置)。

优先三项方向已双审通过；本分支运行候选待实现双审，未合main。基线`cd4169ccbb9cf94b58e29ac6583ff682465a9df2`，仅补现行规则下的读取，未实施同提案其余清单。固定源码/定向证据见[实现记录](../verification/readonly-preview-implementation.md)。

过滤命令与预览共用原解析/规范化及纯校验，set_filter直接输入仍保留原严格类型准入。预览不改当前规则，返回值可本地编辑而不污染所有者；确认仍调用import_filter原串并重新解析校验，不能提交客户端candidate绕过原准入。UI编辑分享串、切换来源、取消或成功后清对应旧确认；不为此添加全局revision、过滤影响扫描或仓库处理动作。Planet关闭自动仍只改变后续继续设置，不取消正在进行的探索。

## 11. 实现候选：装备比较、强化摘要与成交回执

模块正文见[装备分册](contracts/equipment.md#11-实现候选装备比较强化摘要与成交回执)与[强化分册](contracts/enhancement.md#11-实现候选装备比较强化摘要与成交回执)。

设计`0a3a5eb10fa259e3bf1a20d8480a67fc9bbe56d8`已双审通过；本分支运行候选待实现双审、未合main。仅本节读取与回执边界，未搬入b7bb旧缓存/提前通知；历史来源核对留在[提案](../verification/equipment-enhancement-readonly-contract-proposal.md)，固定源码及原始证据见[实现记录](../verification/equipment-enhancement-readonly-implementation.md)。

静态比较止于成长/进化/科研/供能；当前实战值另复用Battle.attribute_details，不拿当前native最终值对比候选charged_base。switch_admission仅复用原单槽换装准入，不承诺最终无人机/Higgs组合许可，实际提交仍沿Session原链。查询只读已接纳事实；_charged_base仅给脱离slot，强化不调用会写_pending_output的evaluate，不设可写展示缓存或临时接纳。

实际执行回执附在原命令结果`purchase_receipt`，不改变原ok/reason或部分成功政策。装备成功提交给`commit_status=accepted`、逐槽purchases[{slot_id,count,spent}]和逐资源合计spent；单槽/批量捕获本次执行quote，不靠钱包差/通知后重读反推。buy_all_levels即使返回后续failure、ok=false，已经成功发布的槽仍给accepted回执。无发布为not_submitted，普通发布拒绝为rejected且无确认成交；提交后fault为fault_unknown、spent=null，不声称回滚。强化购买同样给commit_status、实际count/spent。早期原准入/报价/支付拒绝可无回执，不表示曾提交；没有成功接纳的候选成本不得当实际支出。回执是上次成交，不是下一报价。

报价/比较/选项不锁资源，确认按最新所有者状态重验。装备沿原slots_changed/loadout_changed/options_changed及预算事实刷新；强化采用可见时同步重读，覆盖purchase/改序/分支及外部bonus/armours经accept_output变动，不新增presentation_changed或事件框架。新增强化查询用独立只读输入，经Equipment.accepted_armours复用计数助手，只读已接纳槽；不随_pending_slots变化。原enhancement_inputs/equipped_armours供命令准备的候选语义保持，不要求查询调用方避开装备pending阶段。Session整批接纳结束再刷新；不在模块接纳中提前发信号。当前对象消失清旧详情，输入变化清对应旧报价，保留未提交UI草稿。

### 6.4 共享宿主运行接入候选 H1（已实现，待原审、未合main）

代码`design/shared-host-shell@80e5463f`，来源、真实整屏、环境和23项必要运行观察统一见[运行候选H1](../ui-redesign-plan/shared-host-shell/runtime-h1/README.md)。该候选依据用户后续“继续已授权顶部入口、通用UI、区域契约/真实业务接入”的指令推进，未接管各原组内部设计。

- `shared_host.gd::register_route(id,title,view)`只登记Control/上下文，不解释领域数据；main构建现有模块实例及原callable。8主入口与7更多入口，公开可用性仍按6.1逐项判定，不统一改为Campaign.available。原舰桥页签由现有视图的独立滚动路由替代。
- 装备、当前反应炉视图实现`set_shared_host(enabled: bool, context_slot: Control, backdrop: Texture2D = null)`、`has_exclusive_ui() -> bool`、`exclusive_ui_changed`、`prepare_host_hide(force: bool = false) -> bool`。仅分离全局chrome、上下文和输入生命周期；backdrop本候选不使用。其余当前旧VBox面板由宿主保留实例，内部原生Window由宿主UI树检测；原组新独立全幅场景尚待替换，不假定已经具备端口。
- 视图激活只显隐；焦点撤离，模态未结束拒绝普通切换，实际释放时才force清理。装备批量仍模块自有，公共阻断只作用于顶部和右战场。Space/G共用只读门禁，不改暂停、驻守或拾取逻辑。
- 余额使用Economy已格式化文本，反应炉对象＋等级来自其原presentation_model；无新增领域计算/DTO/广播中心。钱包迁出逻辑HUD，盾甲/航程/统计与投影不动；去掉旧常驻教学文案，快捷键保留。

23项结果仅限当前代码的共享宿主接入。未覆盖已解锁模块全操作、保存/导入/重铸替换全链、新模块美术接入或V0；其准确边界以上述候选记录为准。6.3的反应炉808×835新内容范围继续有效，当前旧反应炉兼容场景不证明旧图获批。

### 6.5 原装备候选与H1的实际组合（候选，未合main）

`design/shared-host-shell@07a36823`已在共享宿主中接入原组`551a4f2b`装备视图，端口来源为原组`da317ba4`交接；源码逐字节保留，未把80e旧装备实现覆盖回来。实际组合、输入记录和来源哈希见[装备×H1交接](../ui-redesign-plan/shared-host-shell/runtime-h1/equipment-owner-integration/README.md)。

沿6.4登记同一808×900视图及context_slot，隐藏重复chrome；保留原组状态工作台、未解锁纯空位和回执显示。共享main仅收窄Window兜底：同时`unfocusable`与`mouse_passthrough`的被动tooltip不产生独占，PopupMenu/FileDialog仍阻断。33项必要组合观察含真实鼠标投影/批量前后投递、原生下拉、Space/G正反对照、实际tooltip与视图状态保留，均通过。

其余模块未因本次接入升级实现状态，星球新场景仍待原组固定Git交接，反应炉仍待新稿。没有新增领域查询/命令/Amount计算；上述结果不等于购买玩法、Session导入重铸全链、V0或Windows通过。

### 6.6 星球R6独立根与H1的实际组合（候选，未合main）

`design/shared-host-shell@8a660076`以原组`b185d5ab`替换星球旧VBox占位，直接登记同一808×900场景，注入原Planet/Crew/协调callable及视觉上下文，保留原组四个最小端口；所有原组面板/领域依赖/贴图/模型/动画文件逐字节保留。现有装备551a4f2b同时保留。具体24文件身份及运行证据见[星球R6×H1交接](../ui-redesign-plan/shared-host-shell/runtime-h1/planet-r6-integration/README.md)。

征服事实/通知和非有限来源校验沿原组Planet文件，不新增宿主领域计算；reforge_requested只导航并预选星球，不触发预览/确认/取消。23项必要接入观察通过，包含自然锁定与明确临时开放/已建设施夹具下的直接路由、原生菜单门禁、Space/G、战场鼠标、状态保留和短时原动画持续；不证明自然建设、全周期视觉、成功重铸全链或V0。根端仍独立审原R6连续视频，不能以宿主通过替代美术/动画视觉通过。

### 6.7 H1原审P2修复候选：预览、焦点与收起（未合main）

代码`design/shared-host-shell@c49ea0a7`，三项根端转交问题及分组证据见[原审P2修复](../ui-redesign-plan/shared-host-shell/runtime-h1/p2-review-fixes/README.md)，待原Astra复核，不扩大V0或美术通过。

- 导入/新游戏预览不是模态输入所有者。候选可显式取消，离开/收起设置使未确认预览失效；确认仍走原事务并校验有效预览。实际重铸事务原保护保持。
- 所有可见UI Control焦点均挡全局Space/G，覆盖根与战场Viewport；战场容器自身焦点是玩法归属，不能误当UI。无模态时战场首击撤焦并消费，后续操作恢复；真实模态不被该路径关闭。
- 收起保留导航当前项、模块单次静态画面、明确状态及就地恢复。原模块隐藏并停止无用视觉，恢复复用同实例；禁止以持续运行模块来维持背景。

本次16项预览、21项焦点、6项收起必要操作通过；正式main/Session/native及固定4.7.2，使用已注明的隔离临时开放夹具。未重跑确认替换/保存全链、自然解锁建设或独立全系统复测，原模块模型/贴图/动画和已关闭标题底板窄修均未修改。

### 6.8 反应炉R4与当前宿主组合（候选，未合main）

`design/shared-host-shell@db94845a`接入原组ae0508ee的R4：外根808×900、内容子根(0,65)/808×835；三/四背景、工作层和reactor_stage逐字节保留。原组旧main黑顶栏不导入，继续现有公共资源/导航及reactor路由。具体来源、同版1440×900和16项必要观察见[反应炉R4组合](../ui-redesign-plan/shared-host-shell/runtime-h1/reactor-r4-integration/README.md)。

reactor_scene只补四个最小共享视图端口、自有caption回收和同一presentation_model快照的共享对象/等级；原局部等级、预算、成本、控件与业务命令保持。绑定/报价/时钟/失效通知及command_finished仍原接线，main/shared_host与Reactor/Economy所有者未改，已关闭P2/裁取实现保持。

本轮16项只证明实际共享接入，使用明确的临时开放夹具，无注资/购级/强推时钟。反应堆原Astra模块审核仍进行，不能据本组合宣布视觉/完整流程/V0或全窗口/DPI通过。

### 6.9 装备ce70按需回执Popup与当前宿主组合（候选，未合main）

`design/shared-host-shell@c84c703f`接入原组ce70b594内部修订与f76d328f交接，保留宿主已审背景退出差异。除_draw/set_shared_host的该差异，原组方法逐字节不变；main/shared_host及其他模块不动。固定来源、1440×900同版整屏及14项必要记录见[装备ce70共享接入](../ui-redesign-plan/shared-host-shell/runtime-h1/equipment-ce70-integration/README.md)。

原组自持PopupPanel及回执字符串，打开时通过has_exclusive_ui阻普通离页/收起并由共同门禁阻Space/G和战场鼠标；force/宿主释放隐藏Popup而不丢回执。原尺寸实测(104,230)/600×420，完整落入模块内容区。只用一次真实+1生成原始回执，未注资；不扩大为模块多资源/长MAX/冷却/四保护全套或视觉通过。装备原Astra仍审，本组合待原布局审核，不合main。
