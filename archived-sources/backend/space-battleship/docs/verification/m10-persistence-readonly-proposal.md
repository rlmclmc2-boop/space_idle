# M10保存宿主摘要与持久化结果：最小待审提案

仅只读源码核对与本地文档提案；未批准、未实施接口/UI/保存动作，不外发。承接[原剩余清单M10行](frontend-readonly-gap-followup.md#其余前端复用与必要缺口清单)，按[设计入口](../game-design/README.md)读取[保存分册](../game-design/contracts/persistence.md)、[M10/V10](../game-design/art/modules/persistence.md)、[06第5节](../game-design/06-data.md#5-新存档格式与生命周期)，重铸损失范围另核[03第7节](../game-design/03-progression.md#7-重铸的完整重置矩阵)。不重做已有通知、教程、敌情、统计或M9。

## 固定核对点

- 本地源码：`feat/amount-safe-previews@c987d46d1a72b286f132a21205735caa5676b42c`。M9仅本地提交、待实现复查；两次push均被自动审批拒绝且未执行，已停止该发布。远端`09af963cf6f66146e019cecd08353426ab6d6abb`不含M9。本提案也不发布；main继续暂停。
- 既有main核对点：`e93c221239a10d377b2ca89dd395ebcfa99c9819`，不宣称最新main。main.gd与SaveFiles完整Git对象相同；Session八个保存/候选方法逐段相同，见[源码审计清单](m10-persistence-source-audit.json)。M9增加接口没有改变这些保存路径。
- 前端需求仅取`design/g1-internal-organizations@a3e05ea05418841821e2acfec6899b900d8d0b90`的`docs/ui-redesign-plan/g1-internal/g2-maintenance-restoration.md`“Godot还原与所有权”和“第四批复审修订R1”：保存状态台/战场同一错误入口、候选与当前目录、持续危险摘要/损失对象、同来源结果及载入/保存区分。浏览器样本不证明真实文件事务。

## 已有事实与副作用

| 所有者 / 已有入口 | 当前事实 | 不能当作纯查询的部分 |
|---|---|---|
| [SaveFiles](../../foundation/host/save_files.gd) `busy/dirty/saved_change/last_result/last_failure` | busy合并worker与待处理请求；dirty比较当前change及payload hash，saved_change是已保存变更号。last_result可能是完成或失败；last_failure在后续成功完成时清除。 | poll会收割结果、改变保存事实并启动下一writer；close会等待并poll；request创建generation、封装快照并可立即启动writer；构造/configure可能创建目录。这些不由状态getter调用。 |
| [Session](../../src/game_session.gd) `dirty_since_save/save_payload` | dirty_since_save复用完整已接纳payload和native长期状态求hash；无保存器时现返回ok/dirty=true。失败保留reason，不能解释为干净。 | save_payload虽不接纳业务，仍遍历各模块并读native，不适合每显示帧重建。request_save增加_change_number、入队并有I/O，不以它试探目录可写性或保存状态。 |
| Session `import_candidate/load_candidate` → `_candidate_from_envelope` | 校验包/配置/领域约束，在候选会话恢复、发放离线微粒，再配置SaveFiles；已有summary={stage,ship,generation,savedUtc}。 | 创建native候选、候选恢复/离线入账及保存器构造；不是“只看摘要”的廉价查询。import/加载失败不安装候选，但不能说这些入口完全无构造或目录相关副作用。 |
| Session `prepare_reforge` + [main](../../src/main.gd) `_preview_reforge` | 原星球/保留列表校验后完整创建候选、重算/开战；summary含planet/start/retained/wallet/round/reset/message。main存候选后持有reforge暂停，只回summary.message。 | 不是模块查询；只由显式预览动作调用。round来自reforge_count，不冒充挑战round_id。取消须释放本操作的reforge原因，不动user/guide/recovery。 |
| main `_preview_import/_preview_new_game` | 导入存已校验候选，仅返回格式化message，丢掉对外结构摘要；新游戏已有directory/target_directory/clear_settings局部事实，损坏旧目录时选择独立目标。 | 都清/写相应pending；新游戏初始化新候选、读存储状态。导入/新游戏当前没有独立cancel入口；不能称只清UI就已释放宿主候选。 |
| main `_apply_import/_replace_session/_confirm_new_game` | 导入确认先给当前会话备份并close成功，再替换。替换成功后request_save，回persistence_pending/persistence_failed/persistence_error；新游戏先写盘、close并回读确认，再替换，随后还有一次保存请求。 | 内存替换、备份、设置保存及写盘都是命令。最终请求接纳不是持久完成；新游戏最后请求失败也不能抹掉它替换前已验证的新存档事实。加载主档/备份现为直接替换命令，不新增隐式预览步骤。 |

## 按实际消费者限定的最小变化

以下方法名/附加字段仅为待审职责描述，不是当前公开方法。保留原返回ok/reason/error/message、命令顺序及失败政策，不新增全局保存状态机、通用事务框架或UI持有的Session。

| 缺口 → 消费者 | 最小透传方案 | 不扩大边界 |
|---|---|---|
| 保存阶段/dirty/最近结果 → 设置保存台与战场失败入口 | SaveFiles给一个脱离的`status_snapshot()`，只投影当前directory、busy、saved_change、last_result/last_failure；main具名`persistence_status()`合并配置是否存在、原dirty_since_save结果、recovery暂停/运行状态及已有startup_save/settings消息。设置页沿现有约1秒可见采样；战场仅消费同一保存错误事实，不每帧生成payload。 | 不调用poll/request/close/read_store来“刷新”getter。dir取当前SaveFiles真实目录，候选路径仍为UI草稿；_startup_directory/偏好在设置保存失败时可能与当前保存器不一致，不能替代actual。无保存器明确标未配置，dirty未知/失败不填false；消息仍消息，不从中文反解析reason。 |
| 排队与worker状态 → 保存动作反馈/状态台 | 原request_save结果的ok/generation原样透传，表示请求已接纳。busy只表示尚有工作；若消费者必须区分待处理和worker运行，仅由上述SaveFiles快照补现有_pending非空及_worker.is_alive的事实，不新增计时器或状态转移。 | worker运行不证明此刻磁盘正写；poll未收割的完成也不能直接宣告成功。没有saved信号，按现行poll后last_result读取，不宣称已有saved(generation,changeNumber)事件。 |
| 持续导入摘要 → 导入确认区 | 在一次显式_preview_import成功时，返回并在原pending中保存`summary.duplicate(true)`及原directory/source输入绑定；之后仅读取这份已准备摘要，不再调用import_candidate。summary沿原stage/ship/generation/savedUtc，不给UI session/envelope/payload。 | generation/savedUtc仍为原规范String，savedUtc指来源档保存时间；不是导入完成时间。不能从路径名或浏览器样本补档案摘要。 |
| 同一重铸快照及损失对象 → 重铸确认区 | 原summary原样深复制透传。若需实际丢弃列表，在现行prepare_reforge成功准备处，以同一旧仓库main+overflow实体ID集合减原drones.retained的已验证ID，补`discarded_ids`与原retained；不由UI重算。挂接现有稳定ID/公开名称；不新造保留准入。 | 原wallet是Amount映射，金额显示若需要，只由提供方用既有to_display最小投影，UI不经float/缩写还原。reset现为说明串，不能声称已有结构化逐字段重置矩阵或从中文拆规则；按03/04既定矩阵展示，缺少的动态逐项结果另审。 |
| 当前新游戏目标/损坏旧文件保留 → 新游戏确认区 | 仅将原准备时的directory、target_directory、clear_settings及“因损坏库改用独立目标”的已有分支事实形成脱离summary；持续读取原pending摘要。 | 不重新扫描目录，不创建或试写目标，不提前reset设置；目标/设置变更清旧候选。原损坏文件仍由既有独立目标策略保护。 |
| 同来源命令结果与持久化进展 → 导入/重铸/新游戏/恢复结果区 | main保留具名操作的原输入绑定（kind及该操作实际source/directory/planet/ids_text/clear_settings），向相应消费者透传原结果；_replace_session最小附原`request_save`返回副本，使generation或原reason/error不被压成message。已替换事实在原替换成功点标明；设置重置的原settings_failed/settings_error独立。加载主档/备份可透传已有loaded.summary。 | 结果与下一预览分别保留；不把另一事务结果挂到当前页面。persistence_error成功时也可能有fallback文本，只在原失败标记为真时当错误。新游戏若需呈现“已有有效新档”，直接透传原verified.envelope.generation的先前验证事实，不再回读或增加写盘；其后保存请求另列。 |

## 绑定、取消及确认的真实限度

- 宿主保持现有每种操作的pending候选与原confirm；UI只持摘要/原输入绑定，不回传候选Session或结构摘要作为提交凭据。新读结果及嵌套行必须脱离所有者；读取不写磁盘、发离线收益、修改pending/暂停或启动候选。
- 目录/导入路径、星球/保留输入、clear_settings变化，或取消/替换会话后，清对应预览及旧结果。重铸复用_cancel_reforge；导入/新游戏最小待审取消入口只释放各自pending，不能发保存、切会话或删除文件。已有confirm对原字符串匹配保留，不擅改为排序/规范化后的宽松相等。
- 当前宿主没有预览ID/来源内容指纹/自动失效框架。仅“改了参数会拒绝”也不完整：改回原输入可能重新命中旧pending；同一路径内容变化不会自动重读。最小透传只承诺展示并确认**已准备的候选快照**，不能声称确认时重新验证最新文件字节或所有活会话事实。若要求这个更强语义，须另审对原准备/确认的定向改动；不以新字段暗中改变事务。
- 原导入预览没有额外暂停当前会话；重铸预览已有reforge暂停。06要求的稳定快照/确认失效与现行具体覆盖不可混同。本提案不新增导入暂停策略、自动取消策略或全局revision，也不把现有按钮guard当所有调用方的原子锁。
- 持久化关联沿真实保存器及返回generation。generation只在该存储/会话语境解释，换目录/换Session清旧关联；saved_change不是generation或时间戳。last_result可能已经被后续失败替换，不能从它伪造完整最近成功历史。若消费者必须显示最近成功generation/UTC，现有saved_change及启动读取不足以保证，需另审最小成功事实保留，当前不承诺。
- 原替换前close失败仍是原拒绝；替换后请求失败为“新会话已载入，保存需重试”，不声称已回滚。原设置目录/偏好保存可能分步失败，不将整条命令包装成全成或全无。重试仍走原命令；不能自动重放导入、离线补偿、新游戏或重铸。

## 未定边界及审核后验证

本提案待定向审核后才可实施。明确待定：是否必须在UI区分pending与worker事实；是否需要最近成功generation/UTC的新增保留；同路径文件内容变化/预览期间活状态变化是否要求确认重验；完整逐字段重置矩阵的结构化来源。它们不由前端样本或本提案自行裁定。

若获准，验证仅覆盖新增截面及原事务：状态深复制和无poll/写入；dirty错误不伪干净、旧完成不清新dirty；队列接纳/worker/同generation成功失败的准确边界；显式预览只构造一次、摘要读取不重建候选；取消和来源编辑清原pending且重铸只释放自身暂停；同快照保留/丢弃ID与实际候选一致；备份/替换/持久失败与设置失败原结果透传、不重放；损坏库新目标与新游戏先验证后替换顺序保持。真实磁盘满/权限/原子替换故障及完整V10仍须独立运行证据。

此次只读代码、比较Git对象/方法、核对文档链接与diff；未调用保存/导入/加载/重铸入口，未读取个人存档、未运行游戏测试。原179项修改与262项未跟踪元数据保留。本地提案不表示M9已发布或实现双审通过。
