# 阶段1模板与四方向：只读模块契约核对

## 身份与范围

- 被核对前端候选：`68a500354d23aa062b3aac43d83c7a7330ce60e1`，入口为 [stage1-directions/README.md](https://github.com/rlmclmc2-boop/space_idle/blob/68a500354d23aa062b3aac43d83c7a7330ce60e1/space-battleship/docs/ui-design-candidate/stage1-directions/README.md)。
- 正式文档/代码基线：`main@96b1e82a7a2a1e5e1247319a56c45f515078575a`，对应[14模块前后端连接契约](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/docs/game-design/14-ui-contracts.md)。14的源码核对标记为08bf2e1e，后续C1及文档合入不把展示候选一起带入主线。
- 未合主线的展示接口候选：`rewrite/ui-review-followup@b7bb3de33287783721a8bbd9417f2ea040ad32ff`。下文明确区分主线已有、候选已实现未合入及需要进一步核对的缺口。
- 本报告封存已回传的只读意见：静态阅读模板、比较、版本边界、JS及相关公开端口。没有运行游戏/HTML、没有GPU或OS点击复测、没有评价四方向视觉优劣、没有改实现或正式规范。

结论：模板的领域边界基本可用，四方向可共用同一套模块契约，不需要四套后台。交互意图可由既有所有者承接，不等于主线接口已齐备、原型已能接游戏或任何方向已通过。阶段1固定样例的边界已明示，不将它们当真实扣费或接纳证据。

## 四方向：前端变化与领域边界

| 方向 | 前端本地状态 | 可承接方式及边界 |
|---|---|---|
| A 全景＋侧浮坞 | 浮坞开合、模块占用空间、战场屏幕位置、选择与草稿 | 显示变换和鼠标逆变换属于前端；主线战斗仍使用同一逻辑几何、炮口和命中。移动/扩展背景不表示有效交火区扩大，不需要后台新增“浮坞位置”字段。 |
| B 下沿工作台 | 工作台开合、观看区缩放、局部滚动与焦点 | 复用相同模块命令与读取口；缩放不能改变战斗计算尺寸或舰体规则。完整装配/护盾/无人机包络与净空仍未证明，不能以示意矩形关闭G9。 |
| C 舱室模式＋战况仪 | 舱室/战场显示模式、战况仪布局、恢复观看入口 | 技术上可用HUD/统计独立查询与原模块端口承接；隐藏绘制不等于停止Session.frame或新增自动暂停。保留唯一伤害回执消费者，不让战况仪自行drain。仅留状态与13“持续可见”的差异仍待上层审阅；本核对不选C、不拒C，也不修改规范。 |
| D 常驻双焦工作场 | 分界位置、鼠标/键盘调整、常驻概览与模块展开 | 都可以保存在前端会话内，不需新增后台业务字段或保存格式。拖动范围/最小显示空间不是业务规则，原型中的数值不由本报告冻结。 |

关闭/重开后保留选择与合法草稿，不需要把它们写入领域保存。对象失效、休眠或候选不再合法时仍需重新核对ID并阻止旧提交；当前值、冷却、余额和任务进度不归前端草稿持有。

## 连续舰装：已有命令与最小展示缺口

主线已有 `Equipment.quote_slot(slot_id,count)`、`buy_levels`、`equip_slot` 以及 `slots_changed/loadout_changed/options_changed`。逐次提交、成功后重读当前值/余额/下一笔报价、普通失败保留工作点并允许查看其他槽，不需要新的连续整备事务或异步任务框架。原型选择、候选、深入展开、焦点与滚动都属于前端。

但卡片所需的结构化事实并未全部在主线页面口中提供：

- 主线 `panel_slots` 主要返回 `id/label`，`panel_equipment` 返回候选 `id/name/enabled`。不能解析label来取得等级、当前装备或冷却。
- 未合入的 `presentation_slots` 已有 `key/level/dormant/ready_at/cooldown/primary/price`；`equipment_comparison` 提供比较字符串，不能将其当成任意结构化属性表或最终DPS。
- 若要接实际卡片/比较，优先审定这些候选接口的接入，必要时最小增补结构化属性、单位和计算口径，仍由所属模块复用实际求值。不能由UI除以攻击周期、拼倍率或套示例值自行生成DPS。
- 静态用途说明可以由前端按稳定装备ID绑定经核对的文案；解锁、费用、有效数值、冷却和可执行性必须取模块事实，不必把所有产品文案做成新的后台协议。
- 真实槽ID例如 `weapon:0`，装备ID例如 `missile`；原型的 `W1` 和中文名称仅是展示别名。换装锁属于本槽及游戏时间，原型固定“10秒”不证明真实到期刷新。

定位：[主线Equipment](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/equipment.gd) 的 `_slot_option/panel_slots/panel_equipment/quote_slot/equip_slot`；[展示候选Equipment](https://github.com/rlmclmc2-boop/space_idle/blob/b7bb3de33287783721a8bbd9417f2ea040ad32ff/space-battleship/src/systems/equipment.gd) 的 `presentation_slots/equipment_comparison`。

## 反应炉：意图、请求与接纳不能混同

阶段1按钮只改变 `model.intent`，不发后台请求，此边界可保留。进入真实样板前，需明确“偏武器/偏防御/留余量”的目标、基准及是否影响其他设备；本报告不替这些意图选比例、固定步长或精确输入。

主线 `allocate_text`、`distribute` 可复用，但有以下限制：

1. `allocate_text` 处理指定模块的目标金额，按现行预算规则保留其他分配、取整并可能截断请求，不承诺收到的请求额原样接纳。免费供能与手动预算必须分开。
2. 候选 `allocation_preview(ratio,inputs)` 只是总容量比例换算；不是结合其他已占额度后的最终可接纳预览，也没有完整的预览拒绝结果。
3. 若阶段2要在确认前核对真实落点，最小缺口是所属Reactor复用 `_allocate/_evaluate` 的只读预览：明确请求额、可接纳额、剩余量/增益及拒绝原因。只读预览不能借 `prepare` 占用提交候选，也不能用“0”字符串掩盖失败。
4. 不可用连续调用多个 `allocate_text` 伪装一次原子全局重分配；中间提交及防御上限调整可能有真实影响。若意图要求跨设备一次接纳，那是另需明确的命令语义，不在本阶段暗增。现有均分则可复用原 `distribute`，但界面应说清点击是在预览还是提交。

定位：[主线Reactor](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/reactor.gd) 的 `allocate_text/_allocate/distribute`；[展示候选Reactor](https://github.com/rlmclmc2-boop/space_idle/blob/b7bb3de33287783721a8bbd9417f2ea040ad32ff/space-battleship/src/systems/reactor.gd) 的 `presentation_model/allocation_preview`。

## 战况及场景事实缺口

- `Campaign.progress_facts` 主要给最高进度和已清关集合，不给原型完整的当前关/点/波次结构；`status_text`也不是可解析的结构化状态协议。若要实时显示这些字段，先确认每项的业务定义与所有者，再给最小只读事实；不能用剩余敌人数或战点数猜“2/3波”。
- `Battle.hud_values/statistics/attribute_details`可支持战况仪的独立查询。`consume_damage_receipts`仍由BattleView单一消费；业务统计不能靠可能截断、已被提取的表现事件重建。
- 科研/星球在阶段1只是观看容量参照，无需因此扩后端。进入真实样板时按14审定 `Research.presentation_model` 等候选进度、人数与任务状态接口，运行/停机必须取实际事实，不用装饰动效冒充工作。
- 选择、展开、模式和分界均是前端状态；普通拒绝后的反馈与危险预览持续展示也属于呈现职责，但必须绑定原命令结果与对象。主线尚未合入的反馈/展示修正仍须按14标版本，不能因文档存在便假定已落地。

定位：[主线Campaign](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/campaign.gd) 的 `progress_facts/status_text`，以及14第2–4节。

## 固定样例的两处接入注意

1. W1的19→20示例价不能直接用作真实请求/必要代价说明；正式规则还涉及进化材料及门槛，应读原报价结果。首要操作信息不能仅因“深入属性按需”而隐藏本次必需材料。
2. `directions.js` 的深入命中方式以显示名称分支判断，“脉冲”会落入“即时命中”的默认分支，与现行飞行激光不符。它是静态样例语义问题，不是新增后台规则的理由；正式接入应以稳定ID与已核对的事实/文案绑定。

来源：[固定样例JS](https://github.com/rlmclmc2-boop/space_idle/blob/68a500354d23aa062b3aac43d83c7a7330ce60e1/space-battleship/docs/ui-design-candidate/stage1-directions/directions.js)、[统一模板](https://github.com/rlmclmc2-boop/space_idle/blob/68a500354d23aa062b3aac43d83c7a7330ce60e1/space-battleship/docs/ui-design-candidate/stage1-directions/template.md)、[版本边界](https://github.com/rlmclmc2-boop/space_idle/blob/68a500354d23aa062b3aac43d83c7a7330ce60e1/space-battleship/docs/ui-design-candidate/stage1-directions/boundaries.md)。

## 收尾

本报告是交互意图与必要契约的静态核对，不是新的正式规范、视觉通过、实现授权或阶段1退出判定。没有更改实现、配置、视觉方案或正式文档，也没有新增独立复测。需要的最小增补均以具体真实接入需求为前提，仍待对应模块确认，不在封存时实现。
