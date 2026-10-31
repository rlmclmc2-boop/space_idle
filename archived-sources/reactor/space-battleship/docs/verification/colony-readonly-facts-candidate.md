# 三项只读事实：独立实现候选

基底：已审修复及审核记录`c2bbf709`，契约`c000d74e`的[14第8节](../game-design/14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)。普通候选分支`feat/colony-readonly-facts`；**未合main，待双审**。第8节只标已审待实施，不据候选存在宣称主线已有接口。

## 实现与边界

- Crew.member_facts：按原成员选项顺序/配置String ID，显式锁定查询只给四个身份/锁定字段；经验余量、原单级门槛、有限显示比例、唯一占用与在线保留原因。门槛Amount及文本按成员等级缓存，行按真实字段/功能状态缓存；restore清除缓存。无新增等级上限。
- Planet.facility_facts：只给实际适用设施。次数/门槛/状态、当前人数、按既有推进条件排序的暂停原因、原领取准入和已领取来源倍率。将原来源求值抽成同一个纯函数，业务贡献与展示共用；静态行在探索完成/领取接纳/restore后失效，人员与running每次从当前输入/状态读取。automatic仅补真实设置变更的原status_changed通知，当前设置的只读输出仍未补。
- Galaxy.node_facts：沿真实String节点键、原最浅可达集合，未揭示不泄露已抽类型；探索/升级是工程量，施工是游戏秒；升级仍按旧等级来源贡献。初始化时保留原节点分配配额（含末节点余量），不为查询重建蓝图/RNG。只读既有来源账本，绝不由查询补账；来源文本与可达集合按相关事实复用。升级余量实际变化即沿原displayed/status_changed覆盖区域。
- 输出均为脱离所有者的数据；没有Session全局路由、存档字段、配置/玩法/比例/预测或UI改造。新鲜人员是调用前提：装配在当前Session显示帧新读Crew.step_assignments/galaxy_assignments后即传；本次只有出口，尚无新UI消费者/装配绑定，探针直接验证新读输入替换旧视图。

## 定向证据

探针：[源码](../../foundation/tests/_colony_readonly_facts_probe.gd)，只加载现行编译配置、真实三个模块及原生FoundationAmount，手动装配局部进度；没有复制业务公式或隐藏平衡表。运行命令沿[原账本报告](galaxy-contribution-ledger-rebuild.md)的两个环境变量，将script替换为`res://foundation/tests/_colony_readonly_facts_probe.gd`。

| 场景 | 核查结果 |
|---|---|
| 成员顺序/未知/锁定/功能未开放，250经验→等级2、余30、下一级144，原等级范围终点 | 通过 |
| 新鲜派遣输入替换旧视图；在线保留/释放后事实与原通知更新 | 通过 |
| 实际设施ID，施工7/180次、ready领取、当前来源与未领取null | 通过 |
| 暂停优先级、零额外人数仍需探索者；探索完成/领取/restore缓存失效 | 通过 |
| 非法/不可用节点，隐藏抽中类型，最浅可达前沿、末节点原配额 | 通过 |
| 探索500/1000工程量、施工15/30游戏秒、升级180/360工程量与旧等级贡献0.1 | 通过 |
| 人员/设施/节点快照修改不改所有者，读不推进/发通知/补账/停止RunState | 通过 |
| 重复读取无Amount调用，经验变化但等级不变不重求门槛pow，静态设施倍率与节点文本复用 | 通过 |
| automatic真实变更有通知、相同设置无通知；仅升级中间进度也进入displayed | 通过 |

[原始事实探针日志](colony-readonly-facts-evidence/facts-final.txt)、[账本回归日志](colony-readonly-facts-evidence/ledger-after-facts.txt)、[入口check-only日志](colony-readonly-facts-evidence/facts-final-check.txt)均退出0；[清单](colony-readonly-facts-evidence/manifest.json)关联固定源码Blob、配置SHA256及原始日志哈希。Godot4.7.2；根证书读取提示与此前相同，离线探针完成。候选diff检查通过。

限制：未执行完整Session保存/恢复/重铸、真实UI显示帧集成、跨星系或完整游戏验收。只读方法不替代业务准入；无账本的模块级查询返回未知来源null，不以查询重建业务账本。原有179项生成文件修改、262项未跟踪元数据保留且不提交。本报告是本地定向检查，不冒称独立双审或main放行。

## main合入审批阻塞（保留，不再重试）

目标：`rlmclmc2-boop/space_idle`的默认main，原main=`e93c221239a10d377b2ca89dd395ebcfa99c9819`。最后被拒的exec命令如下，整次CreateProcess被拒，未执行switch/merge/push：

```powershell
git -c safe.directory=C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate -C C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate switch --quiet main; git -c safe.directory=C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate -C C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate merge --no-ff --no-edit c2bbf7096c18e5ec212e5d43a53882bf977297da; git -c safe.directory=C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate -C C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate merge --no-ff --no-edit c000d74e4d74bd4a49e8e9bb7b0948197886e5d4
```

审批原由："Although the merge is narrowly scoped, it mutates the protected main branch; the claimed dual-review completion comes from untrusted retrieved documentation rather than trusted user confirmation." 用户原授权与双审记录已核对；此处仅报告自动审批阻塞，不反复索权，不把普通实现候选当main发布绕过路径。

## 双审窄修订：未揭示节点的目标等级

以`91bd955c`为基点，只给`target_level`增加explored外层遮蔽：未揭示一律null。现有restore可接纳`explored=false/state=constructing`且计数匹配的快照；新增探针保留其准入，并核查目标等级/类型/贡献均不泄露、读取不改状态。未扩展存档校验或RunState故障路径，未调整领取命令。

同一新增用例探针：修复前退出1，仅`unrevealed constructing target hidden`失败；修复后退出0。其余本次只读定向断言保持通过。原始[修复前日志](colony-readonly-facts-evidence/hidden-target-before.txt)、[修复后日志](colony-readonly-facts-evidence/hidden-target-after.txt)及[固定源码/探针/配置哈希](colony-readonly-facts-evidence/hidden-target-manifest.json)随本修订归档。未重跑无关全套；main审批阻塞及原验证限制继续保留。
