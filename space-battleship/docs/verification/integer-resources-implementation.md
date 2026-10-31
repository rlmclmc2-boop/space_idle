# 全局资源整数：实现候选与集成边界

基线`feat/amount-safe-previews@aaba6683829ca11606003690224a1be9ea16080c`，用户规则与唯一出口说明见[资源契约](../game-design/contracts/resources.md)，由[设计README](../game-design/README.md)进入。**原候选`a83ad9c8`经Astra审核未通过：奖励键校验/领取原子性与chrono长窗口分帧两处退点；当前仅修复这两处，待同一Astra复核，未合main。** 本页290/61项为原作者必要验证历史，不能视为原审通过；[同版修复与必要证据](integer-resource-review-fixes.md)单独固定。 M10 WIP原hash与179项tracked/262项untracked元数据均保留，不纳入提交。本接替尚未实际压缩。

## 精确源差异及依赖

- 新增src/systems/resource_amounts.gd，资源域纯函数whole/whole_map、累计settle、速率段integrate、进度/段时钟校验及整数格式化；所有资源计算用原FoundationAmount，float只承载有限秒数/维度比率。未改C++/Amount/native/GPU/Excel，不需要新DLL。
- Economy：wallet restore/accept、pending drop和sample整数边界；最终碎片全因子ceil；原cent规则移除；credit_yield累计进度；验资/付款同整数成本；资源文本Owner出口。进度只在成功结算后接纳，恢复先校验/转换局部候选。
- Research：funding_progress/funding_meters保存与缺省校验；真实advance用已付服务支持、仅新增费用向上整数扣；预算支持时长/完成资金同源，实际余额和速率分开。
- GameSession：chrono接受时间加入已付服务/段时钟，保存于times，旧档缺省空；材料落账与forge成本规范、forge整数展示字段。没有保存目录、文件提交、checksum或M10事务改动。
- Hyperspace：energy Amount/累计积分/候选恢复/公开文本；固化材料和forge快照规范；材料生成、保底/现代化费用的资源数量乘算保持Amount，原scale10/核心例外和原舍入策略保留。公开energy类型变化必须与消费者字段说明一起接入。
- Equipment仅在已有_quote_levels末端共用整数费用规范，初级特例/Q/MAX/分批算法不重写；Reactor仅新增整数费用展示映射，原_quote/_purchase/purchase/MAX搜索/发布算法不变。Galaxy.income仍只产出未落账原Amount事件量，经Session原credit_yield调用落整数，不改其倍率、10秒事件或UI。
- 本分支落后于各组最新UI。不得复制整个旧树覆盖共享候选；新增helper必须随上述Owner源差异一起带入，按方法冲突合并并保留新UI。energy String、cost_integer_texts、balance_integer_text及Owner格式化调用由既有消费者组接入；未声称当前新UI已无小数。

## 必要证据与限制

[证据清单](integer-resources-evidence/manifest.json)给固定源/基线/依赖及原始日志hash。一个[跨Owner定向探针](../../foundation/tests/_integer_resources_probe.gd)最终290项通过：Economy真实钱包/支付候选、pending drop/sample、历史候选原子拒绝、连续产出分批+中途恢复；Research真实advance每帧钱包整数且1秒与60份相同；Session实际native初始化、chrono每帧整数/分帧、pack/unpack/新候选initialize恢复；Hyperspace普通/后期energy实际advance_online同总时长分帧及中途恢复；旧固化材料奖励、费用转换、极大Amount整数文本。数学上不足1但Amount近似到1的已付进度同样可恢复，不变成每帧重复扣费。

原反应堆×10/MAX61项受付款影响回归通过；当前main check-only退出0；正式日志无ERROR/WARNING。首轮夹具未建立原Campaign可恢复检查点及将1e0误比为字面1导致的恢复断言，不计正式通过，未放宽生产规则。没有独立复测/双审通过声明；未运行新UI、完整游戏、性能、所有故障组合或长期保存。

只读Excel按表格技能读取config/hyperspace_config相关字段，生产manifest导入器把29工作簿重新编译到TEMP；ok=true，hash与验证配置完全一致（308b8f8089750db99e0190526f2f1fde91ee2950c5229567d295860b04d077de）。config autoGenRes=30,2,5,40，chronoSpeeds每秒0..9，Hyperspace参数第42行material_unit_scale=10、energy_rate=10、cap=216000；未修改任何工作簿。临时配置、DLL、基线及用户存档均不提交。

复现沿foundation入口使用现有Godot4.7.2、清单匹配DLL/config，设SPACE_IDLE_NATIVE_EXTENSION与SPACE_IDLE_GALAXY_PROBE_CONFIG后运行上述probe；反应堆回归另设SPACE_IDLE_REACTOR_BULK_BASELINE为c617原Reactor临时Git字节。check-only仍检查src/main.gd。原始引擎日志空行按原字节hash保留。
