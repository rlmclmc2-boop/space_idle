# 唯一实施入口：串行修复与架构收敛

方案日期：2026-10-20。依据：[缺陷审计 A01—A08](REPORT.md)、[架构补审 AR01—AR07](ARCHITECTURE_REVIEW.md)，审计基线 `e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`，已交付审计提交 `6303395d5e5e07318797022bb4eed116758a52b5`。

**这是规划交付，不是产品实现。** 本文件是唯一排程、授权、阶段状态及关闭记录入口。正常顺序为 S00→S01→S02→S03→S04→S04a→S05→…→S24，共26个阶段；S00—S03 已双审、集成所需运行改动、本地验收并关闭；S04 已交付运行候选与审计证据，处于 `review`；后续阶段尚未启动。两个审计报告保留历史结论，不再另建竞争性的实施清单。后续新增问题、拆分阶段、调整顺序和决策均先更新本文件；不能由实现线程自行扩展范围。

整体报告截止为 **北京时间 2026-10-21 11:00（UTC 2026-10-21 03:00）**。截止交付准确的整体状态、已经合入内容、双审证据、未完成和阻塞项，不承诺所有规划阶段此前完成。截止不是跳过验证、把 blocked 当通过、提前合并或降低双审要求的理由。

## 1. 角色、串行纪律与硬门槛

- **父级：**唯一调度者，维护本入口，创建每阶段独立 `sol / medium` 实现线程，独立审查，核对授权，执行允许的 main 集成与本地入口验证，最终关闭阶段线程。
- **本 astra 审计线程：**制定/维护方案、独立审查阶段结果和剩余风险，不实现产品代码。不替代父级结论。
- **sol 实现线程：**一次仅实现当前阶段，提交可复核代码、复现与验证记录；不得开启下一阶段、扩大玩法/数值政策或自行关闭审计争议。
- 用户已授权按阶段串行创建 sol 中等强度线程、关闭已完成阶段。**任一时刻最多一个实施阶段处于打开状态。** 双审可以独立进行，实施阶段不得并行。
- 前阶段必须 `closed` 才可启动下一阶段。前阶段不通过、待核实、缺平台证据或存在未解决项，交回**当前 sol 线程**处理；该线程保持打开，不能用新线程绕过。
- **父级与 astra 必须对同一最终运行 SHA 分别明确 `PASS`，且该阶段未解决项为空。任一方 `FAIL` / `PENDING` / `BLOCKED` 均不算通过；一方不能覆盖另一方。** 两份结论引用相同的完整 SHA、证据快照和审查范围。
- 运行代码或影响结论的证据发生变化后，相应审查重新进行；运行代码 SHA 改变时双方旧 PASS 一律失效。剥离证据、cherry-pick、rebase、冲突解决均可能产生新的最终 SHA，必须对新 SHA 双审。
- S00准备与S01门禁产物独立于后续运行阶段，不合main，不启动产品修复。无运行改动的调查/门禁/决策阶段，双方审相同的审计交付 SHA，运行 SHA 明确记为 `N/A`，不是虚构主线提交。
- 若任务超出一个 sol 中等强度线程能清晰完成的范围，由父级和 astra先共同拆阶段并更新此文件。不得用“做了一部分”关闭原阶段。拆分要覆盖剩余项，并保持前置依赖；不能把已发现的本阶段阻断项挪到以后来取得 PASS。

### 阶段状态机

`not_started → in_progress → review → approved → integrated → closed`

`awaiting_decision / blocked / changes_requested` 是打开阶段的暂停/返工状态，不能跳到下一阶段。`approved` 要求双 PASS；有运行改动时 `integrated` 要求实际 main 集成及本地入口验证完成。证据专用阶段不合 main，记录 `integration=N/A`，在审计材料持久化及双 PASS 后关闭。测试失败可能是测试、环境或实现问题，必须诊断和记录，不能自动归为环境。

任何一个阶段若计划改变已有行为、数据接受范围、迁移损失策略或数值政策，必须先核对决策表。未批准的方案只可调查/比较，不得实施其依赖代码。

## 2. 授权边界与立即需要处理的缺口

| ID | 当前状态 | 权限/决策及默认处理 | 最迟阻断阶段 |
|---|---|---|---|
| P01 | 已授权 | 逐阶段开 sol medium、关闭完成线程；本轮只交付方案，父级随后调度 | 无 |
| P02 | 已授权 | 双审同一最终提交通过后自动合 main，并验证本地入口 | 所有运行阶段仍须满足双审 |
| P03 | 已授权且有限制 | main 仅纳入必要运行改动；测试/日志/截图/审计/临时证据默认只在审计分支；构建脚本若是产品交付必需须在阶段文件清单注明 | S05 等提交范围审查 |
| P04 | 已明确 | main限于必要运行改动；`test/run.py`等验收工具修复留审计/验证交付，不进入运行发布提交。S00准备产物和S01门禁均只在审计分支，main中原A08不据此宣称关闭 | 无权限阻塞；工程门禁与运行阶段分离 |
| P05 | 环境连接及使用授权已确认，具体能力待S00验证 | 父级确认 **BJNLPC-0459 connected、attached、已授权**，阶段线程可直接用于Windows/native/GPU验收，无需新增复测线程。S00核实指定Windows 4.7.2、native构建/匹配DLL、GPU入口及隔离用户目录；连接状态不等于测试已经通过 | 涉及native的阶段及S22/S24 |
| P06 | 清理范围已授权，暂不执行删除 | 仅本轮确认无用且无未合入成果的阶段分支；禁止批量删历史分支/代码。最终由父级核查可达性和双审记录后另行执行，不由本方案工具自动删除 | 收尾；不是跳过保留证据的授权 |
| D01 | 已批准 | 支持持续成长的大数表示，不新增等级上限，保留现有公式及取整规则；容量/分配/剩余量一起遵守。禁止截断、饱和、重置玩家分配或改变免费充能收益 | S09细化工程契约，S10依契约实施；不重复索要已获批准 |
| D02 | 已批准 | 装备成本支持持续成长的大数，不新增等级上限，保留现有公式及取整；单价/批量/扣费遵守同一契约。现有规则可推导的工程实现无需再次请求；确实未定义且会改变经济结果的选择另报 | S09细化，S11/S12实施 |
| D03 | 已批准 | 同一存档只允许一个游戏实例写入；第二实例明确阻止写入，不做多实例进度合并。激活S04a，覆盖所有写入口；这是获批防护，不把原静态风险改写成已复现事故 | S04a列入正常序列，S05必须等其closed |
| D04 | 工程兼容约束，异常时升级决策 | 保持已支持的合法历史存档；核心校验、迁移和恢复不应把旧存档一概拒绝。若必须舍弃状态、缩小兼容范围或做不可逆迁移，先报父级/用户 | S03/S04/S10/S12 |
| D05 | 待证据确定 | 模拟器保留 float 限域并显式拒绝，还是扩大数值域；不允许为“等价”悄悄改玩家战斗。先列能力矩阵，超出纯兼容修复的行为由用户批准 | S20 |

父级转达用户对 D01/D02/D03 的明确批准：助手提出“大数持续成长、无新增上限、保留公式取整”和“同档单写入者、第二实例阻止写入、不合并进度”，用户答复 **“按”**。此授权已生效，不再视为阻塞项或重复询问。P04已由父级按用户“限于必要的运行”核实：验收工具只留审计分支，不合main；D05仅在调查证实需改变模拟器行为时决策。父级记录后续新增答复的来源及日期。`待批准`不会因等待超时、实施便利或报告截止而自动变成批准。工程上可直接做：恢复既有字段、正确选备份、依赖补齐、缓存失效、保留恢复材料、可靠门禁、契约登记和行为保持的提取；它们不授权玩法/数值改动。

## 3. Git 交付与证据分离

审计材料集中到 **`audit/code-review-e3db2838-20261020`**，不得按阶段长期堆积证据分支。实施分支可以短期存在，用于代码审查和返工；所有长期需要的复现/结论集中到本审计分支。

1. S00 记录当前 main 完整 SHA、与审计基线差异和干净工作区。以后每阶段从前阶段实际验收的 main SHA 开始。不要从带有全部审计材料的审计分支向 main 直接合并。
2. sol 在当前阶段短期分支中提交**运行候选**，运行改动与测试/证据分开提交或分开 worktree。父级检查 main 所需文件白名单及每个文件的理由。测试工具依 P04 只留审计分支，不进入 main。
3. 复现脚本、必要测试补丁、日志摘要、失败样例（仅合成）和检查命令归档到 `docs/audits/20261020-e3db2838/stages/Sxx/`。为每项证据标注所验证运行 SHA、引擎/平台、命令、预期/实际和结果；必要时从运行候选构造隔离工程、叠加测试补丁。禁止附带个人存档、凭据、缓存、无必要截图/大日志。
4. 如果先做混合提交，必须先提取成干净的最终运行候选，再进行双审；不得拿混合 SHA 的 PASS 授权另一个 SHA。审计证据更新到审计分支，避免把产品实现混入审计报告提交。
5. 双审针对最终运行 SHA 和冻结的证据快照。优先 main 快进到已审 SHA。若 main 移动或需解决冲突，重新形成候选、补必要验证、重新双审，禁止直接覆盖 main。
6. 合入后读取 main SHA/树与批准对象比对，并在隔离用户目录验证实际本地入口。失败时阶段仍打开，保留现场并交回同一 sol；需要紧急回退时父级先确定安全恢复方案，不能把回退冒称修复完成。
7. 阶段记录、双审和证据在审计分支提交并回读；父级关闭阶段和线程后才启动下一阶段。最终记录允许记录审计提交的父提交/证据快照 SHA，不能为了自引用提交 SHA 反复制造新提交。
8. 收尾对短期分支逐个证明：运行成果已纳入 main 或被明确放弃，必要证据已归档，无独有未合入成果。只登记删除候选，本轮规划不执行删除；保留审计交付分支。

## 4. 串行阶段清单

**所有阶段都继承第 1 节双审关闭规则。** 下表中的“关闭”还必须满足通用门槛，不能只凭本行测试通过。每阶段仅一个明确交付单元；文件数量仅是拆分预警，不是评价质量的指标。若跨越额外子系统或需重写大段核心逻辑，先拆分。建议实现、必要验证、一次返工能在一个 sol medium 工作线程中清晰完成；不以时间到了就强行提交。

| 阶段 / 目标 | 实施范围与排除项 | 前置依赖 | 验收与本阶段退出条件 | 预计设计决策 |
|---|---|---|---|---|
| **S00 基线与执行准备** | 读取当前 main、相关差异；登记任务 ID、平台/工具链/入口、授权及阶段测试清单。仅本入口和证据，不改产品 | 本方案由父级接收 | 记录当前 main SHA、与审计基线差异；P05 逐项 available/blocked；已知失败与夹具问题独立登记。输出下一阶段唯一任务单，双审后关闭 | D01—D03已批准，核对记录；P04已明确为审计侧交付；环境未知不填可用。环境不可用列明确补齐路径 |
| **S01 可靠验收门禁（A08/AR07）** | 在审计侧实现退出码+未预期脚本/解析错误+完成标志的阶段门禁；只接入本轮需要的测试，不全量改几百个测试。不修主线 runner；验收工具修复集中留审计分支 | S00 closed | `SCRIPT ERROR + exit 0` 必须失败；非零/超时/未完成失败；合法通过成功；预期故障输出使用精确声明不吞其他错误。没有假通过后关闭；注明 A08 的 main/审计侧分别状态 | P04已明确审计侧；完成协议是工程决策，不能全局忽略错误 |
| **S02 修复验收夹具基线** | 只处理原 save_policy/config_workbooks 中已知夹具与当前配置不一致、时间戳比较和公式缓存问题；不改游戏公式来满足测试 | S01 closed | 每项失败给出原因和正确 oracle；机制测试用受控夹具，配置测试单独核对；相关专项在 S01 门禁下通过。若暴露新产品缺陷先登记并修订阶段，不删断言取得绿灯 | 若时间语义未定义需父级/astra确认；改变离线收益/时间政策需用户批准 |
| **S03 持久字段与便携往返（A01）** | 最小版本化字段契约，连接保存/导出/导入清洗/导入前备份；8 个缺失顶层字段及 sample.production_time；保持严格校验 | S02 closed | 每个既有持久字段有归属和往返断言；AI 等级/研究进度、生产时间、换装期限保留；未知危险数据仍拒绝；正常保存及导入前备份均验证 | 本地绝对时间/可迁移时间的既有语义若不明确，先列决策；不自行重置 |
| **S04 完整恢复选择（A02）** | writer 与无副作用迁移/语义校验接口、明确加载结果；主档/备份均用同一规则；不做全存档系统重写 | S03 closed | 完整备份+`{version:5}` 主档不会丢进度或覆盖有效备份；主/备都坏时安全失败并保留现场；合法历史版本可加载；失败不得修改 live state。关键恢复矩阵通过 | D04；多实例策略 D03 不混入此阶段 |
| **S05 游戏发布依赖（A03/AR04）** | 玩家产品必需资源清单，staging/检查共用；补 3 项依赖并核对直接依赖；不迁移素材目录 | S04a closed | 空 staging 含全部必需配置，缺项明确失败；初始化数据库/新档/保存重开；目标 Windows 构建和实际产物验收可放 S22，但本阶段仅关闭依赖修复，不宣称发布获批 | 构建脚本作为必要交付工具列 main 理由；P05 未满足的最终验收保持 pending |
| **S06 独立分析器依赖闭合（AR06）** | 分析器独立产品脚本/数据清单；核对静态缺失 23 个直接依赖以及动态依赖声明；保留既有外部工作簿约定 | S05 closed | 从空目录构造分析器，必需依赖无缺项；指定引擎导入及最小分析入口运行通过；无借用开发工程未声明文件。只修产品依赖，不重写模拟器 | P05 指定平台能力；若改变“便携/邻接工作簿”产品约定，先批准 |
| **S07 反应炉缓存正确性（A05）** | 只补既有升级事务的必要缓存/revision/编译配置失效，不改成长数值 | S06 closed | 激活免费充能、预热缓存后升级，缓存值与新鲜计算一致；配置 revision、事件和 native guard 无重复；正常无奖励路径不退化 | 无新增玩法决策；native 断言缺能力不可用脚本结果替代 |
| **S08 配置事务可恢复（A06）** | atomic_batch 与编辑器备份关系；失败保留恢复材料/清单、返回明确恢复状态。只处理证实的安装+回滚失败，不宣称完整跨文件 ACID | S07 closed | 单失败回滚和二次恢复失败注入；A新/B旧时必须有可核查的旧版本恢复材料；重试/人工恢复路径明确；成功路径清理合理 | 恢复目录/保留策略由父级/astra审；自动删除用户数据或不可逆修复须另批 |
| **S09 数值政策关口** | sol 仅调查/提出容量、分配、费用、批量、取整/显示/存档/native范围表与方案；不改产品；把已批准D01/D02落实为可检查的工程契约 | S08 closed | 策略文档含旧规则、边界样例、迁移兼容、拒绝/支持范围及已批准D01/D02的逐项映射；父级/astra审同一方案 SHA 后关闭。仅新发现且原规则无法推导的政策问题待决时暂停，不重复询问现有授权 | D01/D02已有明确答复；保护既有进度，不能借工程细化改公式/取整/上限 |
| **S10 反应炉数值闭环（A04）** | 按 S09 容量→分配→剩余→倍率及展示/保存的最小闭环；不动装备成本 | S09 closed 且 D01 approved | 97/98级与倍数提前越界、足额/不足额、分配/重载、免费充能；扣费前验证，不出现容量0/NaN/静默截断；native支持/拒绝符合能力约定；旧档不丢分配 | 新发现取整/比例问题返回 S09 决策记录，不临时选策略 |
| **S11 装备报价数值核心（A07上半）** | 按 D02 在审计侧实现单级/批量成本大数原型及比较测试，形成可正式接入的实现；本阶段不合main、不改购买命令和UI，避免未使用代码进入main | S10 closed 且 D02 approved | 普通范围费用及取整结果与旧规则一致，显示误差不得改变实际扣费；3873级、超float批量、几何求和/取整边界通过；原型与旧接口的映射明确；本阶段运行SHA为N/A，S12正式接入后重新双审 | D02；采用近似算法或改变逐级/总价取整需用户批准 |
| **S12 报价到交易接入（A07下半）** | 购买、批量求和/扣费、报价缓存、显示及保存中相关消费者；不改伤害成长 | S11 closed | `{m:1,e:400}`等合成资源可按契约交易；不足额不改状态，成功恰好扣费；单次与批次按已批准取整一致；UI无INF，重载正确。至此才能关闭 A07整体 | 沿用 D02；若消费者过多先拆分本阶段，不边改边扩大 |
| **S13 状态投影契约（AR02）** | 给 durable/portable/suspended/native/simulation 建字段归属表和核查，不强迫共用一个schema；补已知AI字段的比较签名；不重写对象图序列化 | S12 closed | 每类边界明确保留/排除字段理由；新增字段缺归属能被检查；选定往返/alias/revision不变量覆盖；差异明确，不把清点当运行证明 | 不同边界的有意排除经父级/astra审；如涉及游戏状态损失转用户批准 |
| **S14 配置命令协议试点（AR03）** | 用反应炉一个命令落地guard→结算→修改→revision/失效→脏标记→通知；不批量迁移全Game | S13 closed | S07/S10行为保持；拒绝不扣费、不发完成事件；成功一次失效/通知，旧配置待结算时间不受新配置污染；协议可复用且副作用清楚 | 执行顺序必须保持现有时间语义；改变收益需批准 |
| **S15 船员命令接入** | 仅 crew assign/changed 接入 S14协议，保留crew效果计算和UI | S14 closed | 船员切换前后pending时间、缓存/native快照、save_dirty与事件验证；普通和拒绝路径一致，无重复结算 | 行为保持；新发现时序歧义先停当前阶段审定 |
| **S16 AI与行星的局部接入** | 仅 AI完成/峰值变更及planet activate的配置提交出口接入；不重写科研调度或行星系统。任一需要深入时拆为S16a/S16b后仍串行 | S15 closed | 两类入口分别覆盖成功/拒绝、revision、缓存、保存及事件；既有AI/planet专项通过；live Dictionary外部写入未全面消除则显式登记 | 不改变研究速度、峰值、建筑效果和解锁规则 |
| **S17 银河重配边界** | 仅 prepare_region_refit / native advance 相关配置提交和pending结算适配，不重写银河排程 | S16 closed | 切换/暂停/恢复前后pending在线时间守恒，旧新效果边界明确；native交接身份和失败状态正确 | 跨时间边界收益不确定时用户决策；P05是实际native验证前提 |
| **S18 超空间配置提交** | 仅 publish相关提交协议及主线挂起/返回接口核对，不改票据、挑战规则和对象图格式 | S17 closed | 主线→挑战→返回状态保留；guard拒绝不部分提交；缓存/生命约束/分配/事件符合原规则；既有状态专项通过 | 新格式迁移/返回时收益政策须批准，不自动修正 |
| **S19 测试能力声明（AR07）** | 本轮所需测试的引擎/native/GPU/fixture/runner描述表和准备检查，替代仅凭文件名猜测能力；不批量改所有历史测试 | S18 closed | 需要native的handoff/numeric_range等可在指定环境获得正确扩展；缺能力明确BLOCKED；非native测试不误装依赖；S01门禁仍有效 | P04已确定审计侧工具去向，P05决定能否关闭 |
| **S20 执行器能力矩阵（AR05）** | 列玩家/实验/native的数值、效果、时钟、RNG、移交范围；调查balance float接口，提出兼容修复或明确限域方案 | S19 closed | 每个模式标 supported/rejected/unknown及证据；不能以exact名称宣称等价；用户批准需要改变行为的D05后关闭 | D05待决则停；不默默提高范围或改变玩家结果 |
| **S21 小型跨执行器差分门禁** | 限定固定seed、代表性装备/效果和升级/暂停/移交/返回检查点；采用S20范围，不全组合穷举 | S20 closed | 支持交集内检查状态、伤害/目标、RNG和队列身份；不支持输入显式拒绝/既定回退；原生实际运行证据；发现差异交回当前线程定位，不改oracle掩盖差异 | 若差异修复改变规则，回用户决策；P05必需 |
| **S22 目标产品验收** | 指定Windows引擎/native/GPU；真实玩家包与分析器入口、新档/保存/重开、代表性操作；不做全平衡或长时认证 | S21 closed | S05/S06构造的实际产品运行通过、错误日志干净、运行数据完备；无开发路径借用；原生能力与S20一致。环境不足保持BLOCKED | P05；不能用Linux替代发布验收 |
| **S23 有限架构提取（AR01）** | 只把battlefield.create_battle_game中的会话装配提取成明确factory/组合入口，保留初始化顺序/provider/数据库/原生策略；在审计侧更新错误架构定位（不随运行提取将文档合main）。若无实际依赖收益则提出不实施理由双审，而非机械搬行数 | S22 closed | 主入口行为和S21检查点不变；依赖与可写owner明确，Game规则未拆散；实际入口再烟测。不得扩展为main/game全面重写 | 父级/astra决定提取边界；行为变化不在授权内 |
| **S24 收尾与整体报告** | 对最终main运行必要受影响回归/入口检查；核对A/AR状态、审计证据归档、剩余风险、短期分支删除候选；不新开重构 | S23 closed | 最终main SHA与双审链一致；所有阶段记录齐全、无遗失成果；报告明确修复/缓解/未解决/未验证，附用户决策；父级完成允许的收尾。截止先到时交付中期整体报告，当前阶段继续保留真实状态 | 不擅删分支；不以全阶段关闭推导零遗漏 |

### 阶段 S04a：同档单写入者（D03已批准，已纳入序列）

- **目标/范围：**在同一存档写入口建立所有权保护，覆盖普通保存、导入和恢复提交；第二实例阻止写入，不合并进度。不阻止用户运行程序本身，除非用户另有批准；不得自动删除其他实例有效锁或存档。
- **前置：**S04 closed，D03已批准。S05依赖S04a closed，不得自行略过。
- **验收：**在BJNLPC-0459用合成存档双进程验证：同档仅一个writer、第二实例没有tmp/bak/主文件写入；持有者退出/崩溃后的再获取有明确安全规则；不同存档互不阻塞；正常保存/导入/恢复回归。需验证OS锁语义，不能仅靠PID文件存在性猜存活。
- **设计决策：**D03决定用户可见行为；实现采用何种OS级排他机制由父级/astra审查；若需要抛弃用户编辑、强制退出或自动合并，另请用户批准。
- **退出：**双审同一最终运行SHA PASS、零未解决项、main集成与本地入口验证、记录归档及线程关闭；否则返当前sol。若跨平台锁/导入事务耦合超出单线程范围，先共同拆分为“所有权机制”和“写入口接入”两个串行子阶段，不削减验收。

### 阶段大小与范围升级

S03/S04、S10、S12、S17可能因现代码变化而需拆分。S00先核对；实际工作中新发现必须分解时，只能由父级与astra共同确定新的原子交付单元、依赖和完整验收。原阶段转为显式容器，不把未解决项算关闭。每个子阶段仍独立sol medium、串行双审。同一阶段因返工持续由原sol处理，不能为赶截止改成多个并行修复线程。

## 5. 审计问题到阶段的映射及关闭口径

| 问题 | 主要阶段 | 可以认定关闭的条件 |
|---|---|---|
| A01 | S03，S13防复发 | 三种传输/备份路径和持久字段往返证据齐全 |
| A02 | S04 | 语义残缺主档不遮蔽有效备份，失败不覆盖，合法旧档兼容 |
| A03 | S05，S22目标产物验证 | S05仅修依赖；目标发布验收需S22，不提前称Windows发布通过 |
| A04 | S09/S10 | 用户批准数值契约，完整容量/分配链验证通过 |
| A05 | S07，S14防复发 | 已复现缓存案例修复且native相关配置不陈旧 |
| A06 | S08 | 双故障恢复材料保留且恢复可操作；不扩称全部崩溃原子性 |
| A07 | S09/S11/S12 | 报价核心与交易消费者全链路完成；S11单独不关闭A07 |
| A08 | S01/S19 | 区分审计侧门禁与main runner；按P04主线runner不修改，该处缺陷保持未修，不以审计工具替代宣称关闭 |
| AR01 | S13/S23及S14—S18 | 只声称选定边界收紧；Game/main其余职责集中继续列剩余风险 |
| AR02 | S03/S04/S13 | 选定字段契约与边界核查完成；全历史迁移/所有图形状未穷尽 |
| AR03 | S07/S14—S18 | 指定命令协议接入并有时序证据；其余写入口列出未覆盖 |
| AR04 | S05/S08/S13 | 产品必需配置契约与安全事务收紧；19 JSON来源未证实项仍显式unknown |
| AR05 | S20/S21 | 仅在已声明能力交集等价，未知/拒绝范围不能称支持 |
| AR06 | S05/S06/S22 | 两产品闭包和产物通过；未引用素材不随意删除 |
| AR07 | S01/S02/S19/S23 | 本轮测试入口/能力/定位可靠；不声称全仓测试体系已治理完毕 |

未纳入默认修复的范围：全量C++内存/线程审计、所有数据值/Excel公式平衡、GPU长时泄漏、多实例进度合并（明确不实施）、所有历史存档版本组合、所有测试逐项执行、全部外部直接写profile迁移及素材授权。需要扩大时先新增有边界的阶段；不能把它们藏在“收尾”。

## 6. 唯一阶段状态记录

**S00—S03 均为 `closed`；S04 为 `approved`；S04a 与 S05—S24 均为 `not_started`。** S00 证据见 [stages/S00/README.md](stages/S00/README.md)。S03 实施线程 `01a15a8e-35c8-7632-8baf-8af7060310cd` 已归档，运行 SHA=`0d01530bdce168a55d0ce7c835f17072d66d6bc7`，main 与实际本地 `D:\放置` 均为此 SHA，隔离用户目录入口验证通过，临时分支清理完毕；其关闭记录已经完成，旧句“待父级统一关闭”已失效。P05 已核对当前会话的 `hostname.exe`/DNS 主机名为 `BJNLPC-0459`，`COMPUTERNAME` 环境变量与 `.NET MachineName` 显示旧名称 `DESKTOP-I3QUONB`；固定 DLL 已实际加载，源码重新构建仍未验证。S00—S03 均已获父级与原 astra 对各自同一对象的双 PASS 并完成关闭。S04 运行候选与审计侧证据见 [stages/S04/README.md](stages/S04/README.md)；双审、main 集成、本地入口验收及阶段关闭仍待父级执行。

### S00 关闭记录

```yaml
stage: S00
status: closed
implementation_thread_id: 01a15a4c-ea59-75a6-afea-513fefe8a0c0
model: sol
reasoning_effort: medium
base_main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
scope_and_allowed_files:
  - docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md
  - docs/audits/20261020-e3db2838/stages/S00/README.md
  - docs/audits/20261020-e3db2838/PLAN_VALIDATION.json
  - docs/audits/20261020-e3db2838/PLAN_SHA256SUMS.json
decisions_required: []
decisions_received: [D01, D02, D03, P04]
runtime_final_sha: N/A
runtime_tree: N/A
main_file_justifications: []
evidence_snapshot_sha: 015c2204be0fa8391187479851930105e55429c1
verification:
  commands_and_environment: ["详见 stages/S00/README.md；当前会话 hostname.exe/DNS=BJNLPC-0459，COMPUTERNAME/.NET MachineName=DESKTOP-I3QUONB"]
  results: ["main 与基线相同", "当前环境 Godot 4.7.2/匹配 DLL 加载/GPU 最小入口/隔离目录可用", "hostname.exe 与 DNS 主机名均为 BJNLPC-0459"]
  unverified: ["native 源码重新构建及新产物", "真实玩家产品入口与发布包"]
parent_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: 015c2204be0fa8391187479851930105e55429c1
  record_path: stages/S00/FINAL_REVIEW.md
  unresolved: []
astra_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: 015c2204be0fa8391187479851930105e55429c1
  record_path: stages/S00/FINAL_REVIEW.md
  unresolved: []
integration:
  state: N/A
  main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
  approved_sha_matches: false
  local_entry_command: null
  local_entry_result: not_run
closure:
  evidence_persisted_and_read_back: true
  parent_closed_stage: true
  implementation_thread_closed: true
  closed_at: 2026-10-20T17:33:23Z
  next_stage_allowed: true
branch_cleanup:
  candidate: null
  unique_work_checked: false
  evidence_preserved: true
  deletion_executed: false
```

### S01 关闭记录

```yaml
stage: S01
status: closed
implementation_thread_id: 01a15a61-fd87-7064-a145-397991b320e8
model: sol
reasoning_effort: medium
base_main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
scope_and_allowed_files:
  - docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md
  - docs/audits/20261020-e3db2838/PLAN_VALIDATION.json
  - docs/audits/20261020-e3db2838/PLAN_SHA256SUMS.json
  - docs/audits/20261020-e3db2838/stages/S01/README.md
  - docs/audits/20261020-e3db2838/stages/S01/gate.py
  - docs/audits/20261020-e3db2838/stages/S01/test_gate.py
  - test/test_save_policy.gd
  - test/test_config_workbooks.py
decisions_required: []
decisions_received: [P04]
runtime_final_sha: N/A
runtime_tree: N/A
main_file_justifications: []
implementation_candidate_sha: 044c3c19f8fa8f788d5d7328005ac42d46b33d03
evidence_snapshot_sha: 624c903395c65d756a0c88cae1fd9b59b303d3fa
verification:
  commands_and_environment:
    - "Windows / Python 3.12: python docs/audits/20261020-e3db2838/stages/S01/test_gate.py"
    - "Windows / Godot 4.7.2: 隔离目录运行 evidence/probe_test_gate.gd；详见 stages/S01/README.md"
  results:
    - "六类合成进程门禁样例均按预期通过"
    - "真实 Godot SCRIPT ERROR + exit 0 被门禁拒绝"
  unverified:
    - "S02 两个既有专项尚有已登记夹具失败，留 S02 处理后在本门禁下运行"
prior_review_of_044c3c19:
  parent: "PENDING；行为核查通过，唯一阻断是入口仍标 S01 not_started"
  astra: "FAIL；唯一阻断同为入口状态与双审记录缺失"
parent_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: 624c903395c65d756a0c88cae1fd9b59b303d3fa
  record_path: stages/S01/FINAL_REVIEW.md
  unresolved: []
astra_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: 624c903395c65d756a0c88cae1fd9b59b303d3fa
  record_path: stages/S01/FINAL_REVIEW.md
  unresolved: []
integration:
  state: N/A
  main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
  approved_sha_matches: true
  local_entry_command: null
  local_entry_result: not_run
closure:
  evidence_persisted_and_read_back: true
  parent_closed_stage: true
  implementation_thread_closed: true
  closed_at: 2026-10-20T17:54:11Z
  next_stage_allowed: true
branch_cleanup:
  candidate: null
  unique_work_checked: true # 仅使用保留的审计分支，无独立临时分支
  evidence_preserved: true
  deletion_executed: false
```

父级每次状态变化更新本节下的对应记录。可附详细审查文件，但最终状态以本入口为准。没有完整SHA、明确PASS和零未解决项，不可写closed。

```yaml
stage: S02
status: closed
implementation_thread_id: 01a15a74-7e6c-77de-a595-0654cf22a0d4
model: sol
base_main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
predecessor_closed_sha: 87fab83acecd6933d6a86ca50b172742333d1654
scope_and_allowed_files:
  - test/test_save_policy.gd
  - test/test_config_workbooks.py
  - docs/audits/20261020-e3db2838/stages/S02/README.md
  - docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md
  - docs/audits/20261020-e3db2838/PLAN_VALIDATION.json
  - docs/audits/20261020-e3db2838/PLAN_SHA256SUMS.json
decisions_required: []
decisions_received: []
runtime_final_sha: N/A
runtime_tree: N/A
main_file_justifications: []
implementation_candidate_sha: 696e7c9affe7eb94c8d98454add13e6863d95ec0
evidence_snapshot_sha: c2cfe0795450638e1351923d1c986f519a3aadd0
prior_review_of_2613962e:
  parent: "FAIL: endpoint-only local-time oracle can reject an intermediate save second"
  astra: "FAIL: endpoint-only oracle can also accept stale UI text inside the interval"
verification:
  commands_and_environment:
    - "Windows / Godot 4.7.2 / Python godot-native venv: S01 gate.py test_save_policy.gd --headless"
    - "Windows / Godot 4.7.2 / Python godot-native venv: S01 gate.py test_save_policy.gd with window"
    - "Windows / Python godot-native venv: S01 gate.py test_config_workbooks.py"
  results:
    - "save_policy headless: 51 checks, 0 failures; S01_GATE_PASS"
    - "save_policy windowed: 53 checks, 0 failures; S01_GATE_PASS"
    - "config_workbooks: 14 tests OK; S01_GATE_PASS"
    - "minimal reproductions and oracle sources: stages/S02/README.md"
  unverified: []
product_defects_found: []
parent_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: c2cfe0795450638e1351923d1c986f519a3aadd0
  record_path: stages/S02/FINAL_REVIEW.md
  unresolved: []
astra_review:
  verdict: PASS
  reviewed_runtime_sha: N/A
  reviewed_evidence_sha: c2cfe0795450638e1351923d1c986f519a3aadd0
  record_path: stages/S02/FINAL_REVIEW.md
  unresolved: []
integration:
  state: N/A
  main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
  approved_sha_matches: true
closure:
  evidence_persisted_and_read_back: true
  parent_closed_stage: true
  implementation_thread_closed: true
  closed_at: 2026-10-20T18:22:25Z
  next_stage_allowed: true
```

### S03 review 记录

```yaml
stage: S03
status: closed
implementation_thread_id: 01a15a8e-35c8-7632-8baf-8af7060310cd
model: sol
reasoning_effort: medium
base_main_sha: e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3
predecessor_closed_sha: 6486727dfec23a94a0f9cce93ffc2da8610bf6ad
scope_and_allowed_files:
  - space-battleship/scripts/save_transfer.gd # 唯一运行文件
  - test/test_save_transfer.gd # 仅审计分支
  - docs/audits/20261020-e3db2838/stages/S01/gate.py # 仅审计分支门禁接入
  - docs/audits/20261020-e3db2838/stages/S03/README.md
  - docs/audits/20261020-e3db2838/stages/S03/reproduction.json
  - docs/audits/20261020-e3db2838/stages/S03/LOCAL_INTEGRATION.md # 仅审计分支
  - docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md
  - docs/audits/20261020-e3db2838/PLAN_VALIDATION.json
  - docs/audits/20261020-e3db2838/PLAN_SHA256SUMS.json
decisions_required: []
decisions_received: []
runtime_final_sha: 0d01530bdce168a55d0ce7c835f17072d66d6bc7
runtime_tree: 10bf32ba2e060cde7269b6f54459a989e5b5538b
main_file_justifications:
  - "space-battleship/scripts/save_transfer.gd: 便携字段白名单与清洗原本丢失八个已持久化字段及 resourceSamples[].production_time；仅补契约，不改既有时间语义"
evidence_snapshot_sha: e187f60aea5d5d0aad86718416914af915d44032
verification:
  commands_and_environment:
    - "Windows BJNLPC-0459 / Godot 4.7.2 / Python 3.12: baseline e3db2838 的 save_transfer.gd 与审计测试叠加，在隔离目录运行"
    - "Windows BJNLPC-0459 / Godot 4.7.2 / Python 3.12: PYTHONIOENCODING=utf-8 python docs/audits/20261020-e3db2838/stages/S01/gate.py test_save_transfer.gd --headless --godot D:\\CodexTools\\godot-4.7.2-stable\\Godot_v4.7.2-stable_win64_console.exe"
    - "git diff --check e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3 944f8e65a77d1a5dfc2bf0fee2ecd6fc933188cc # 本地同 tree 候选"
  results:
    - "基线复现：8 个顶层字段与 sample.production_time 缺失；测试退出 1"
    - "最终候选：SAVE TRANSFER 154 checks, 0 failures；S01_GATE_PASS"
    - "远端运行 SHA 与已测试本地 SHA 的 tree 同为 10bf32ba2e060cde7269b6f54459a989e5b5538b；运行差异仅 save_transfer.gd"
    - "main 和 D:\\放置 本地 HEAD 均为批准 SHA；实际玩游戏.cmd 入口隔离 user data 运行 120 帧退出 0；入口、导入与游戏日志错误模式匹配数均为 0；详见 stages/S03/LOCAL_INTEGRATION.md"
    - "s03/durable-portable 删除前与 main 同 SHA，无独有未合入运行成果；远端分支删除后 GitHub 回读为 404 Branch not found"
  unverified: []
parent_review:
  verdict: PASS
  reviewed_runtime_sha: 0d01530bdce168a55d0ce7c835f17072d66d6bc7
  reviewed_evidence_sha: e187f60aea5d5d0aad86718416914af915d44032
  record_path: stages/S03/FINAL_REVIEW.md
  unresolved: []
astra_review:
  verdict: PASS
  reviewed_runtime_sha: 0d01530bdce168a55d0ce7c835f17072d66d6bc7
  reviewed_evidence_sha: e187f60aea5d5d0aad86718416914af915d44032
  record_path: stages/S03/FINAL_REVIEW.md
  unresolved: []
integration:
  state: integrated
  main_sha: 0d01530bdce168a55d0ce7c835f17072d66d6bc7
  approved_sha_matches: true
  local_entry_command: "SPACE_BATTLESHIP_VERIFY_WINDOW=1 SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES=120 SPACE_BATTLESHIP_ENGINE_PATH=D:\\CodexTools\\godot-4.7.2-stable\\Godot_v4.7.2-stable_win64.exe; & D:\\放置\\玩游戏.cmd"
  local_entry_result: "PASS; exit 0; 120 frames; isolated user data; 0 entry/import/game error-pattern lines"
integration_review:
  reviewed_evidence_sha: 4b125cb6cbafb883d8dd641eee714fe0ea3ac133
  parent_verdict: PASS
  astra_verdict: PASS
  unresolved: []
  scope: "仅真实入口 120 帧启动验收；不扩大为存档重开或完整产品验收"
closure:
  evidence_persisted_and_read_back: true
  parent_closed_stage: true
  implementation_thread_closed: true
  closed_at: 2026-10-20T19:12:40Z
  next_stage_allowed: true
branch_cleanup:
  candidate: s03/durable-portable
  unique_work_checked: true
  evidence_preserved: true
  deletion_executed: true
  deletion_command: "git push origin --delete s03/durable-portable"
  deletion_result: "exit 0; GitHub branch read-back 404 Branch not found"
```

### S04 review 记录

```yaml
stage: S04
status: approved
implementation_thread_id: 01a15abc-a83d-709a-990c-b376f407b0ec
base_main_sha: 0d01530bdce168a55d0ce7c835f17072d66d6bc7
runtime_final_sha: abb68a7f7014dafee73c2f8c48a856aaddec0456
runtime_tree: a1107e72f18d011cd693ef5e9b2447ac14abf940
runtime_files:
  - space-battleship/scripts/game.gd
  - space-battleship/scripts/progress_writer.gd
  - space-battleship/scripts/save_transfer.gd
evidence_entry: stages/S04/README.md
field_contract: stages/S04/FIELD_CONTRACT.md
evidence_snapshot_sha: c345de52867a38a2cc0db6baadb2a53b2daa37aa
verification: "Windows Godot 4.7.2 isolated S01 recovery gate 126/0 PASS; S03 transfer gate 155/0 PASS; S02 policy 51/0; startup rejection 7/0; historical disk migration 15/0; hyperspace state 284/0; save boundaries 21/0; current v5 47-field probe exact"
decisions_required: []
compatibility: "v2-v5 稀疏历史磁盘档仍可加载，但不能遮蔽完整备份；缺失 highestLevel 和稀疏档负资源仅在磁盘副本上按旧默认值迁移，便携导入保持严格拒绝；无弃档或不可逆迁移"
prior_review: "父级与原 astra 对 d51d9cab/e04e6a9a、3d24f84a/e7736cd1 均明确 FAIL；反例及返工见 stages/S04/README.md；旧审查不适用于本 SHA"
parent_review: {verdict: PASS, reviewed_runtime_sha: abb68a7f7014dafee73c2f8c48a856aaddec0456, reviewed_evidence_sha: c345de52867a38a2cc0db6baadb2a53b2daa37aa, unresolved: []}
astra_review: {verdict: PASS, reviewed_runtime_sha: abb68a7f7014dafee73c2f8c48a856aaddec0456, reviewed_evidence_sha: c345de52867a38a2cc0db6baadb2a53b2daa37aa, unresolved: []}
review_record: stages/S04/FINAL_REVIEW.md
integration: pending
closure: open
next_stage_allowed: false
```

```yaml
stage: Sxx
status: not_started
implementation_thread_id: null
model: sol
reasoning_effort: medium
base_main_sha: null
scope_and_allowed_files: []
decisions_required: []
decisions_received: []  # ID、批准者、原文/摘要、时间/来源
runtime_final_sha: null # 无运行改动填 N/A
runtime_tree: null
main_file_justifications: []
evidence_snapshot_sha: null  # 审计分支冻结的证据提交
verification:
  commands_and_environment: []
  results: []  # pass/fail/blocked/not_run + 预期/实际
  unverified: []
parent_review:
  verdict: PENDING
  reviewed_runtime_sha: null
  reviewed_evidence_sha: null
  record_path: null
  unresolved: []
astra_review:
  verdict: PENDING
  reviewed_runtime_sha: null
  reviewed_evidence_sha: null
  record_path: null
  unresolved: []
integration:
  state: pending # 无运行改动N/A
  main_sha: null
  approved_sha_matches: false
  local_entry_command: null
  local_entry_result: not_run
closure:
  evidence_persisted_and_read_back: false
  parent_closed_stage: false
  implementation_thread_closed: false
  closed_at: null
  next_stage_allowed: false
branch_cleanup:
  candidate: null
  unique_work_checked: false
  evidence_preserved: false
  deletion_executed: false
```

审查记录至少包含：审了哪些文件/契约、复现/回归证据是否足够、是否有无必要main文件、设计授权是否满足、每条问题如何处理、最后的PASS/FAIL/PENDING/BLOCKED。不允许只有“看起来不错”。记录已有PASS后代码改动，先把双方状态重置PENDING再继续。

### 每个sol线程的固定任务单

父级从本文件复制当前阶段定义，填入：阶段ID、前阶段closed记录、base main SHA、精确允许范围、已批准决策、必要测试命令/平台、证据目录、Git分离要求、禁止行为和退出条件。任务明确：只实现本阶段；测试/证据保留审计分支；报告最终运行SHA及证据SHA；等待父级和astra双审；任何一方返工在本线程处理；不得自行合main/开下一阶段/改数值政策。

### 截止时整体报告格式

截止时父级即使仍在实施，也须交付：最终已验证main SHA；已关闭阶段与双方PASS对应SHA；当前打开阶段/线程及阻断；已修/未修A01—A08；AR风险缓解边界；已执行与未执行平台测试；待决策/权限项；下一唯一阶段；证据位置与保留/清理候选。未完成项目逐项写明，不以测试数量或截止时间包装为整体完成。
