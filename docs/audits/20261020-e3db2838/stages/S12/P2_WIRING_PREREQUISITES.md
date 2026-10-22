# S12/P2 接线前置清单（方案修订，未实施）

权威：[P2 方案](P2_INTEGRATION_PLAN.md)及其引用的唯一入口。main 定位固定于 `31e79337741bf9860d69fff21dae6be994dacd00`；P1 源定位固定于 `163ad3dba4131036446faaa37a6073b513fb3be1`。下列“拟”是供双审的实现协议，不能当已证明范围。只补正确性/接口清单，不增加压力矩阵。

## A. 编码和边界：现有支持、内部资产、P2 义务分开

| 输入/边界 | main 实际接受/行为（源码定位） | P1 已有资产与未证明范围 | P2 拟接线及失败语义 |
|---|---|---|---|
| 非负 int/float 资源 | GrowthNumber.valid:6-9 接受有限非负数；int 为 Godot signed int64，float 含小数/次正规数。game:423-426 将普通数字加载为 float；这不证明 >2^53 的 bare JSON 整数无损。 | sparse_wallet.blocks:144-145 可转换整数和有限 float；非负 float 的二进制有效载荷转有限十进制。Python finite host 不是实际加载证明。 | 不把小数 floor/ceil 成整数；合法旧浮点值保留原业务值。现有 bare JSON 资源整数若有原始 token，可用资源字段专用读取保留确切整数；已经舍掉的历史位不猜测恢复。新保存大整数不用 bare float。 |
| 旧 m/e | GrowthNumber.valid:9 仅两字段；m/e 为有限 int/float，1<=m<10，e==floor(float(e))，e 可为负且可大至有限 binary64 指数量级，**不是 int64 指数域**。 | P1 sparse_wallet:138-143 用字符串整数位置转换；旧 mantissa 走既有 decimal_factor 约定，不能悄悄改成新的理想实数价格。有限 legacy trial 不证明所有指数/格式性能。v4 packed position 不覆盖全部该域。 | 必须接受 main 合法旧域；指数先按实际有限整数值转有符号数字串，不 int(e)/展开空指数带。转换约定与旧数据值及 P1 oracle 对照；不能把 e 超 int64 改判非法或归零。 |
| 已合 main 的 ReactorInteger v1 | ReactorInteger.valid:7-10：恰好 {v:1,i:canonical_digits}，i 无符号无前导0，数值 **>9007199254740991**；int 非负也合法。make 可用 int64 承载，encode 在 >2^53-1 时带标签。GrowthNumber.valid 接受此标签；不限于“曾未合候选”。 | 任意长度数字串的内存/保存成本未有全域证明。 | 资源严格解码保留全部位；0/小数字的伪 v1 不能由宽松解析新接纳。除实际资源字段外沿用原 ReactorInteger 契约。 |
| 候选钱包 v2 | main GrowthNumber.valid 不接受。注意这与顶层存档 version=2 完全不同。 | P1 compact_wallet:140-150：五字段 v/base/sign/delta/places，places 0..1074，正余额，delta 规范；仅内部转换资产。 | 不新增历史兼容义务，不为候选格式单独迁移全存档。不能未经审查把 raw v2 接入正式资源 schema。 |
| 候选钱包 v3 | main 不接受。 | P1 sparse_wallet:95-105：{v:3,blocks:[{p:有符号规范字符串,d:非零整数}]}，p 严格递增，d 在 [-5000,4999]，最高块正；位置字符串不受 int64 限制，零由普通0编码。 | 可复用算法，外部历史支持不自动继承。原候选进度无恢复承诺。 |
| 原型钱包 v4 | main 不接受。 | bench_sparse:22-42：{v:4,blocks:[[position_string,digit]]}；位置必须可转 int64 且往返同字符串，空块唯一零；digit 非零且[-5000,4999]，递增、最高正；carry 在 MAX_I64 报 unsupported。 | 只作已证明的查询局部快路径；不得用 v4 位置上限拒绝合法旧 m/e，超域转任意位置资产。raw v4 不作为历史支持义务。 |
| P2 新资源存储（拟冻结 CW1） | main 尚无此格式。 | 不宣称 P1 已验证此新 schema/真实保存。 | 为避免冒认候选历史格式，拟仅资源字段新增 {currency_version:1,blocks:[{p:String,d:int}]}。base=10000，p 为任意长度规范有符号十进制整数（无+、-0/前导0），严格递增；d 非零整数[-5000,4999]、最高正，空数组唯一零；恰好两顶层字段/两块字段。规范化、carry/borrow、负结果、alias、JSON 对照必须实证。新 writer 输出 CW1 后读回是必须义务；raw v2/v3/v4 仍不因内部复用而被接受。非资源字段不放宽 GrowthNumber.valid。 |
| 装备等级 | database.max_equipment_level:116-118 返回 2147483647（注释为存储边界）；game:2797/2805/2857 为 int(current)、current+1、current+levels；portable schema 的 loadout.level 为 i，shape:186 要 abs(float(value))<9.22e18。**查询哨兵、int64 host、JSON 接受域不相同**。 | Python host:85 检查 1<=level<=MAX_I64-count；Godot MAX:200/303 等直接加法，不构成全域 checked-add 证明。P1 仅有限起点/跨度实证。 | 窄接口先校验正整数 level、count>=0、闭区间末级和所有后继，再 checked add；不能让 current+count 溢出后变负/空报价/0购。2^31-1 不能当新玩法上限；移除该哨兵依赖所需的 database.gd 最小适配列白名单。int64外等级/原存储外等级不是 P1 已支持：需准确 representation_error，零写入，保留现场并交回同线程；不得包装成已完成持续成长或用新上限关闭 P2。若实现确需扩展等级表示，先提交具体链/方案双审，不能顺带全局数字改造。 |
| start+count 与算法哨兵 | 旧 range(current+1,current+levels+1) 额外要末级+1；MAX loop 还要 level+=1。 | 指数括界 count*=2、二分 lo+hi、start+256、tier+1 也可能先溢出。P1 finite host 的一处检查不覆盖 Godot这些算式。 | 先比较 count<=MAX_I64-start，区间使用包含末端且无末端+1的结构；二分 lo+(hi-lo)/2；括界 checked growth。不能 int(float(count))；所有必要末端/进位用精确整数 helper，无法表示报明确错误。level/count 及其存储/native边界未证明前是未解决项。 |
| 材料 | hyperspace_state.valid:72 的 C.integer 只测有限整数（hyperspace_config:100-101），存储 schema 又是 i；不是 signed int64 全域精确证明。运行材料按既有非负 int64 域，不扩大钱包域。 | _material_due:197-204 以三角数差精确 helper 累计，但 start+count、tier+1 仍有 Godot int 风险。Python host 检查 0..MAX_I64；Godot 冷场景只用2^53-1，未证明 >2^53 JSON往返。 | M(n) 用大整数中间量计算，不先 int64 乘加，再比较预算与既有 MAX_I64。退款余额+材料先 checked add，末项超域整批零写。>2^53 原始材料 token 需字段专用无损读取；输出/读回不得经过 binary64 丢位。不接受材料 CW1/v2/v3/v4 来扩域。 |
| native 等级/属性传输 | native_execution_compiler.native_integer:12-13 限 [-2147483648,2147483647]；compile:36-43/133 对升级映射/装备等级使用它。故即使 host 为int64，也不代表DLL接受超2^31等级。 | P1仅协议模型，未证明实际kernel全数值域；native_scalar还要求有限int/float，精确钱包不得投影后塞进descriptor。 | 保持现有native能力检查；超域在任何相关配置写入前走已存在的安全legacy handoff，成功后继续精确钱包交易；handoff失败零写该槽并报告未解决。不能把native32位变成游戏等级上限，也不放宽compiler检查冒充C++已支持。C++/DLL协议扩域仍不在白名单。 |
| 保存边界 | SaveTransfer SUPPORTED_VERSIONS=[2,3,4,5] 是**存档版本**；MAX_BYTES=16MiB，shape depth<=48。现有精确 token 恢复只针对 reactorAllocation；progress_writer:202-212→prepare_disk_data。_compose_save_data:751-756 只特别编码铀。 | 模型保存/v4编码不证明完整 ordinary/backup/portable/import；P1 无全存档规模承诺。 | 保留版本迁移/恢复顺序及现有16MiB portable预算，不新增余额/块数/指数永久限制。新资源专用 schema、资源/材料/必要等级 token 校验共用于普通、备份、portable和candidate Game；新数据自身 roundtrip。超过既有文件预算或分配失败明确 resource/storage_error，保留live与恢复材料，不能丢低位取得成功。 |

CW1 只是一项明确的待双审提案，不因列出规范取得运行 PASS。若复用任意位置资产不能覆盖 main 合法旧域或精确收支，不降级到 packed int64 来宣称完成。等级超出现有宿主表示、JSON高位、MAX材料/后继算式是已登记证明缺口；“有报错”是安全失败证据，不是能力通过。

## B. 异步 MAX 协议（拟）

### B1. 三类对象及最小依赖

- **PriceCursor/Certificate**：只依赖成本行全内容、evolution 配置、规则版本、cost key、起点/请求数。价格缓存不依赖钱包、战斗攻击计数、炉峰值、无关收入字段；普通精确前缀和费用界可跨钱包变化复用。目标槽身份/起点变化不能用旧结果提交，但相同起点价格资产可复用。
- **QueryRequest**：request_id、owner身份/代次、目标槽/顺序、配置/解锁、**请求捕获的资源/材料预算**，持有深快照/不可变 ledger value。按该固定预算求 MAX，排队有公平工作份额；后来的收入不改变该查询输入，不触发从头定价。只读预览不会自动排队购买。UI明确预算取样时间、结果为“本次预算可买”，不声称计算结束时实时钱包的数学最大值；这是异步快照语义，待本方案双审，不冒称 main 已有。
- **PurchaseQuote + CommitTicket**：quote内容固定为 start/count/逐资源费用U/材料M/模式/证书/配置指纹，并保留该预算的边界证明；ticket另绑定当前 owner/代次、相关余额/材料、槽/解锁和请求消费状态。钱包任何变化都使旧 ticket 失效；不会让 P1旧host票继续提交。查询资产可以完成，失效仅表示票不可执行。

查询状态是 pending/complete/stale/cancelled/error；提交状态另为 committed/rejected/stale，带 changed_slots。任何 int/bool 都不代表 pending。complete 本身没有运行写入、升级事件或save_dirty。

### B2. 持续收入下推进、预览与确认

1. 捕获预算后继续同一只读计算。相关收入只改变当前 ledger/ticket，不丢弃费用工作；无关资源变化连预算比较都不必重做。配置/解锁/槽/profile替换使旧请求 stale；同值替换和ABA也不能复活票。科研/购买等钱包减量无需清空定价缓存；已完成内容仍可展示，执行前再看能否支付。
2. completed 只发布不可变报价内容及“取样预算/取样时刻”；UI不自动刷新成另一价格。同一槽多次刷新复用活跃 request，同一用户重复点击不创建并发购买；新预算刷新是明确新请求，可复用 PriceCursor。
3. 用户确认的是**显示的 start/count/U/M/模式/证书内容指纹**。确认时若旧 ticket 因钱包变化失效，先使其不可执行；用同一已确认内容和当前owner/余额/材料同步建立新 ticket，再同步重验并精确扣同一U/M，期间不yield/不重报价。当前不足、配置/槽/解锁/profile替换或重复消费即拒绝，零写入；UI要求重新请求/确认。金额/数量/模式变了必须重新展示确认；正向收入也不会偷偷扩大数量或改变费用。
4. 该“同内容、当前绑定的新票”是 **P2拟补充协议**：不放宽旧票失效规则，也不声称原 P1 已证明。新票只复用已确认的快照预算 MAX 证明，不声称该数仍为当前余额最大值。待双方审定其与同报价契约一致才实施；若不同意快照预算/新票绑定，必须先共同给出替代协议，不能回到每帧全钱包重启。
5. 自动船员的到期调用是购买意图：捕获一次预算并登记request，不把计算完成当成交；到期意图的同内容 quote 经当前绑定/支付重验后才可提交。期间继续游戏与正常收入/科研；同成员 pending 时不重复入队、不追补错过间隔；成功回执才 invalidate_member，取消/失败不冒充成功。不得冻结经济 tick、锁钱包、延迟其他收入或保留全局cashflow事务。

### B3. 多槽和单次 native 聚合

- batch请求捕获一次预算，从 weapons→defence、索引顺序生成虚拟逐槽计划；每个成功槽从该请求的虚拟余款扣同一U/M，失败槽不扣并继续。每槽quote绑定本槽输入余款，而非各读初始钱包；快照之后的收入留在live，不能被覆盖。
- 所有计算跨帧阶段只读。确认后先建当前执行票；实际逐槽同步提交，后槽使用当前 live 扣掉前槽实际成功后的余款，但不自动增大已确认的数量。前槽因经济/依赖失败而未买，重新核验后槽同内容费用是否可付，不错误消耗它的虚拟费用。零数槽维持零购，不偷偷变为新MAX。
- native预测不再调用同步 max_upgrade_amount_slot；prepare_numeric_batch 改为消费已完成 BatchPlan/quotes（精确费用、before/after、顺序、成功槽和配置摘要），与游戏共用一次计划。只在最终同步命令内取得**当前**native owner/player/执行域快照，构造并预检一个聚合描述符，不跨帧持有可提交描述符。
- 同步单槽的原resources_changed→属性失效/防御差量→upgrade顺序保留；每次事件重入后重验下一槽依赖。自己的前序成功由回执推进期待状态，不误判外部stale；外部变化则停用原聚合预测。不得回滚已经合法成功槽。其余槽按协议重新核验经济计划；若无法安全交接则停止后槽，保留成功前缀。
- 最后只对实际成功配置编译/安装**一次**聚合描述符；不把预测失败槽安装进去。事件导致计划偏离、native拒绝或晚失败时走已有安全handoff，禁止安装旧descriptor；handoff失败就停止后续配置操作，报告prefix回执。只有成功槽发布upgrade，upgrades_completed最终只发一次且列实际成功槽。同步边界内不推进combat；描述符编译/重验成本纳入既有heartbeat实测，无法预算内完成则保持未解决，不扩大为C++重写。
- 这保持逐槽部分成功，未改成批次全有或全无；退款仍独立整批原子。request开始和最终回执各有一次生命周期，重复回调/确认不能二次扣款。

## C. 必要调用点迁移（行号固定 main）

| 调用点 | 现状 | 迁移协议 |
|---|---|---|
| game:2781 max_upgrade_amount→2785 max_upgrade_amount_slot | 同步int wrapper | 改返回typed MaxQueryOutcome，key解析为首槽后转request/poll；没有pending→0兼容层。 |
| game:2792-2824 max_upgrade_amount_slot | 同步逐级扫描，whole-wallet signature/cache | 拆只读request/poll/cancel及成本游标；固定预算、完整非钱包依赖；不在can_upgrade_slot/UI每次刷新中重复启动。 |
| game:2901-2903 upgrade_max | int→bool即时购买 | 改购买请求/报价/明确confirm/receipt接口，复用同内容ticket；不能返回bool表示已排队。 |
| equipment_tab:313 update_card_cost、323 upgrade_card、806 act | 刷新/点击直接要int，点击直接upgrade_slot | 刷新只poll/申请预览；pending显示计算中且禁用确认；complete展示quote；card/inspector确认精确quote指纹；取消/换选取消订阅，晚回调校验request/selection身份。普通1/10仍同步upgrade_slot bool。 |
| game:2875-2899 upgrade_equipment_batch | 返回bool；native先独立预测，再同步每槽MAX | 改BatchRequestOutcome（pending/terminal+changed_slots）；普通1/10可立即terminal，MAX按B3；统一计划，bool成功含义只从最终changed_slots得出。 |
| crew_system:340-352 due/handler bool、361-365 auto_upgrade | bool决定invalidate_member，timers事先清除 | 唯一生产batch调用方：按typed outcome分支；pending登记成员/request，不invalidate、不重排队；terminal回执消费一次。其余crew handler bool接口保持，auto_upgrade专用适配；不是把整个crew调度改async。补入运行白名单。 |
| native_execution_session:303-328 prepare_numeric_batch，310 MAX调用；331-340 commit_numeric_batch | 同步预算副本+自行MAX | 接BatchPlan，移除独立MAX/重新定价；配置/玩家状态最终同步重验，只一次聚合提交/安全handoff。 |
| dev/qa_stage4_7.gd:46；dev/qa_evolution_assert.gd:39/54 | 显式int/bool断言 | 属验收消费者，改用审计目录overlay/探针等待terminal并断言无提前写；不把测试修复放运行候选。 |
| player_loadout_generator:257-272→fleet_battle_runner:191 | 指定delta同步升级；不是MAX | 保留同步指定数购买与错误；预算改typed max/补足，不引入MAX请求或float(max)。 |
| reactor_panel:455/527、balance_autoplayer:109 | reactor_max_upgrades独立int | 不是装备MAX调用，不顺带改异步协议；只适配共享铀账本，性能仍实测。 |

wrapper签名变化与所有生产调用方在同一纵向提交集合交付；不能先让Dictionary塞进旧int/bool再称局部通过。未找到的动态调用在实现前以确切调用链补清单；不以本次静态grep声称穷尽动态外部脚本。

## D. 资源读写与复制位置（main对象）

全部以 `space-battleship/scripts/` 为前缀。R=读，W=写，C=复制/替换，S=存储；不表示所有位置必须修改。

| 位置 | 类别与封闭方式 |
|---|---|
| game:184/197 fresh_profile、423-426 load_progress_data | W/C：初始值、加载专用校验、owner初始化/换代；合法值不能默认零。 |
| game:945-955 upgrade_currency/can_afford_upgrade_costs | R：区分材料/资源typed compare；禁止float(cost)判定精确可支付。 |
| game:960-970 refund_equipment、1093-1097 refund_all_equipment | R/W：先汇总逐级旧价、全部货币材料预检，一次提交；原循环边返还边失败被替换。 |
| game:1286/1303/1321 reactor预算和扣费 | R/W：共享铀受控入口，保持S10普通域公式/累计；不改reactor capacity/allocation表示。 |
| game:1714/1719 reforge next.resources/profile=next | C：深独立编码与owner换代；不是把旧owner仅revision++后继续用旧profile对象。 |
| game:2685-2721 collect（2708钱包、2712 run_resources） | R/W：源值先准备入账成功才删除来源；samples/run/事件用原amount，不用余额差。 |
| galaxy_system:130-150 advance（142钱包） | R/W：生成公式/采样顺序不变，只对资源入账做转换，失败不消耗来源。 |
| ai_tech_tree:103 snapshot；145-175 advance余额/不足/清零/扣费；194资源事件 | R/W：有限不足额专用转换、原小数与微量规则；不只有175写点换算法。 |
| game:2787-2803 signature/budget copy；2853-2857货币/材料/等级写入 | R/W/C：成本游标非钱包依赖、请求预算深快照、同票同步提交；材料和等级先验证不溢出。 |
| native_execution_session:304-321 budget/player/projected | R/C：共用计划替代浅钱包副本/重复计算，不跨帧保存live player alias。 |
| player_loadout_generator:260-272 profile替换、270补预算、272返回；fleet_battle_runner:189-195/251 | R/W/C：测试预算/生成器专用受控初始化与换代，不是生产收入；深返回不影响live。 |
| game:726-756/767-774 ordinary/portable/_compose；progress_writer:202-212；save_transfer:153/178-212/prepare_disk_data、318/353/371 | C/S：资源专用schema及确切token，普通/备份/import candidate一致；导出不改live，内部ticket不入JSON。 |
| equipment_tab:535/548/624 observed_resources；main:932 resource_text；reactor_panel:507 | R/C：深观察、正确失效/投影，不把display送回扣款。 |
| main:382-383 --capture-all直接资源赋值 | W：仅capture测试入口，但也改为受控合成初始化/owner失效；不是遗漏的生产收入，验证不得向个人存档写入。 |
| balance_autoplayer:85/121；balance_game:282-295 | R/C：费用评分、支出统计适配typed值/明确有限投影；禁止float字典、投影回写。 |
| balance_metrics:46/113-115/154；balance_timeline:93/107；balance_analyzer:69-70；balance_views:86 | R/C：输出深复制、投影超域显式结果；不重写完整模拟器或用0/INF冒充数据。 |
| game:1811/1824 production/resource_minute_total；ai_tech_tree:85 record_income | R：读取样本而非钱包；审查其调用下游保持source amount，不因新账本扩域生产/峰值。 |

写入白名单补“生成器/capture 的受控合成初始化”；不允许任意第三方字典直接写或复用生成器补预算于玩家交易。hyperspace_main_return/manual session 的 run_resources 继续收入统计域，native掉落从collect边界回流；事件重入到profile的路径按B3复核。

## E. 同线程实施顺序与当前结论

1. **窄接口与清单**：双方先审本方案修订及CW1/快照预算与确认协议；冻结现有支持域和所有checked算式，准备隔离候选；未实施前不虚报边界已通过。
2. **逐段纵向接入**：价格/账本→普通购买/退款/科研/收入→MAX及全部调用方→native/保存/投影；每段构建/直接正确性核对，但始终是同一个打开的P2，局部绿灯不关闭P2、不自行合main。
3. **整体验收**：沿原方案第4节同一压力矩阵/真实游戏验收，不增轮次/压力档。冻结同一最终运行SHA与证据SHA后父级+现有astra双审；表示边界、持续收入推进、确认/事件/native/存储未解决项非空就不通过。

本轮仅方案修订与接线清单。旧方案评审结果为方向认可、进入运行修改未获通过；本修订仍待双方回读，不自行把反馈当运行授权。
