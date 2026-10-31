# 星球累计征服只读口：实现候选

分支`feat/amount-safe-previews`，实施基线`1865da2f03912fdc7b961fadf0c91fc378edd608`。设计已获根审及原星球独审限定通过；**本实现待原双审、未合main，不代表完整M7/V7或游戏验收**。唯一入口仍为[设计README](../game-design/README.md)，字段正文见[Planet第11节](../game-design/contracts/planet.md#11-实现候选当前星球征服事实与累计来源摘要)。M10 WIP与179项已跟踪、262项未跟踪元数据均保留，不纳入候选。

## 出口与所有权

- `Planet.conquest_facts(planet_id: String) -> Dictionary`成功给`ok/planet_id/conquered/shared_experience/rewards`。未知或实际未开放返回`ok=false/reason=PlanetLocked`；参与源值缺失、非数值或非有限及最终非有限返回`PlanetConquestSourceUnavailable`，不写RunState。校验先于原_buff、int转换及共享经验布尔判断；包括原max可能掩盖的非有限输入。
- rewards每行给`kind/target/value/unit/display_text`：`level_bonus/equipment`与`level_bonus/enhancement`为原int等级、unit=levels；`free_charge/all`为原float比例、unit=ratio且提供方显示百分比；`luck/all`为原float幸运值、unit=luck。仅全体已接纳征服的累计来源，不含未来奖励、设施收益、最终全局效果或逐球奖励。合法无征服仍是已知0/false。
- `_conquest_bonuses`共用于原贡献初始化及新读口，四次求值顺序、原_buff遍历/叠加和原int/float不变。读口不调用贡献初始化，不触碰_factors、设施缓存、领取候选、通知队列或状态；新字典与嵌套行脱离所有者。
- `Planet.conquest_changed(changed_planet_ids: PackedStringArray, cumulative_changed: bool)`仅成功accept_reforge与restore_state真实赋值前捕获首基准，deferred比较本批最终标记和四项来源；同值及A→B→A零事件，发信号前清空旧批基准，重入独立排队。标记变化可独立于累计变化；拒绝、读取、prepare_reforge只读预览、普通探索/人员/设施行为不新增征服事件。候选Planet实例执行restore_state/accept_reforge同样可排队并按净差发信号；保证的是候选事件不传当前页面、不改旧会话，而非候选对象绝不发信号。
- 原`availability_changed/is_available/planet_options`继续决定选择有效性，新信号不替代开放刷新。restore后的原Session刷新顺序不变。信号和deferred回调均属于Planet实例，无Session全局路由。消费者仅绑定正式当前Session，换Session必须断开旧实例连接或以实例身份过滤旧回调，再初读新实例；不将候选实例通知转发旧页面。本候选不改消费者UI，实际隐藏/重开和换Session页面接线仍由星球组验证。

## 定向证据

[证据清单](planet-conquest-readonly-evidence/manifest.json)固定源文件、原Git基线、依赖与日志SHA256。使用现有Godot4.7.2及既有native/config，不创建新工作区、不导入资产、不写个人存档。

- [所有者探针](../../foundation/tests/_planet_conquest_probe.gd)：69项断言，原1865da2f的Planet源字节直接作对照；覆盖非连续星球、多球add/mul/max与原int/float、当前球未征服但其他来源生效、共享经验按本球、零值、锁定/未知、读取纯度与深改隔离、冷/陈旧贡献和领取候选缓存、首写基准、批合并、净回原值、标记/累计分别失效、重入、成功/失败重铸、原开放链及旧所有者队列隔离。NaN/±Inf分别在等级、免费比例、共享经验的max源中先拒绝。
- [生产配置与Session探针](../../foundation/tests/_planet_conquest_session_probe.gd)：226项断言，实际Session/native初始化与publish_world接纳，逐个累计征服集合比较读口四项、原贡献和Session发布副本；本球共享值及读取纯度一致。开放gate是显式边界夹具，不代表自然游玩解锁；原实际is_available仍过滤读口。
- 两探针及当前main入口check-only均退出0，正式日志无ERROR/WARNING。最初受限证书库提示和夹具遗漏原restore后开放刷新不计正式通过证据，修正后正式运行。
- 原_buff、探索/经验/设施算法、贡献发布、Session/native及所有消费者源码逐方法不变核对见清单。未运行完整重铸事务、完整游戏、UI集成、性能或长期保存；所有者实例隔离不等于已验证消费者断连/身份过滤。

## 复现与交接

按foundation入口使用同一Godot4.7.2。将1865da2f的`space-battleship/src/systems/planet.gd`原始Git字节写到临时.gd，设置`SPACE_IDLE_PLANET_BASELINE`。所有者探针以`--headless --path . --log-file <临时日志> --script res://foundation/tests/_planet_conquest_probe.gd`运行；Session探针另设`SPACE_IDLE_NATIVE_EXTENSION`与`SPACE_IDLE_GALAXY_PROBE_CONFIG`后运行对应脚本；入口检查用`--check-only --script res://src/main.gd`。不得提交临时基线、DLL、生成配置、缓存或存档。

本接替执行者尚未实际压缩；原执行已实际压缩仅作为交接历史，不冒报本接替状态。固定候选交原双审后等待，不自行扩大范围或合main。
