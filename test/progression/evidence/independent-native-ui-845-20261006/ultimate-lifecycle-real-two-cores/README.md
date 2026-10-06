# 真实2核心：845白色究极生命周期独立复验

原生付费链可行：白色究极space:1:2还原→按真实alpha记录现代化→再究极，核心2→1→1→0，等级10→10→20→20。三次实际发布事件且重复点击、三个付款后存档恢复均未复扣。原附加词条保留；全部其他无人机、装备/收藏/预设/仓库/溢出/封存/挂设/传奇状态、材料及历史不变。未注入资源、未改价、未改父档，未长跑。

## 真实来源与同版构建

父Git证据提交 `8ab0ef05109d6e0b90822546d6b90df59cc52c06`，`parent-845/actual-two-core-source/`，原件 `save_periodic_185401.json`，X1=185401.399978375，通60后1.0914444441902824h。压缩SHA `4d21d561a9bac9305d647d5fff780b3530f72afc6abbc89057382e48029dbdbe`，解压SHA `2f61c5c26094236fc4a293854deb9edb04a08c3105d0a3f40e100258d5976887`，本机取回并核对，未修改。

干净845源码 `845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5` 新建887文件项目，指纹 `4e07f51458d778fa152222ab0d39042cc07f4d7f83d2e1c563479de5e4123983` 与父真实存档一致；导入只改16个.import，其余清单哈希一致，没有热合fb439。原进度含跨版本前缀与45恢复，本窗口正式加载重生成，不能称全程同版自然进度。

正常图形窗口Godot4.6.3、Xorg :90、llvmpipe；菜单及预览/付款按钮均原生输入。时间字段仅在内存重基准以隔离离线收益，恢复后暂停，保留原币值；实际正在进行的auto beta60保存状态保持，不让后台进度产生新资源。不测FPS、不代表RTX3090。该来源超过1.09h，本次隔离支付不能倒算为1h内原全身完成。

## 精确交易

| 操作 | 原生报价 | 实际核心余额 | 等级/究极状态 |
|---|---|---|---|
| 原始机 | 真实双核心、白色、laser、等级10、附加T4全局暴伤0.256 | 2 | 10 / true |
| 还原究极 | 核心1，持有2 | 1 | 10 / false |
| 现代化 | 简并态物质0，持有4 | 1 | 20 / false |
| 再究极 | 核心1，持有1 | 0 | 20 / true |

目标20由当前真实history.alpha的5/10/15/20且≤highest61取最大得出，不取beta60，不假设目标。原affixes为空，所以按现公式现代化材料0；此结果验证合法链，不代表对设计意图作新决定。

究极附加词条完整保持 `{key:global_critical_damage,tier:4,value:0.256,locked:false}`，未重随机，forge_rng_state保持，forge_revision从2到5。还原时只停用附加词条，再究极时恢复生效并按真实level20计算；blue_source_bonus、origin_quality、legendary、legendary_effect、hanging_slots、hangings等保持原值。三个实际事件为forge_restore_ultimate、forge_modernize、forge_ultimate。

[还原报价](native/02-restore-quote-screen.png) · [实际扣第一核心](native/02-restore-result-screen.png) · [真实10→20现代化报价](native/03-modernize-quote-screen.png) · [再究极扣第二核心](native/04-reultimate-result-screen.png) · [最终真实已付款档恢复](observer-retest/final-actual-checkpoint-restored-screen.png)

## 重复点击、恢复及观察器失败记录

每次支付后，原生再次点击同一个已禁用付款位置：完整业务状态不变。各付款后通过portable_save_data导出实际状态，再从该实际JSON走正式load_progress_data/resume：语义完整异空间状态均保持，没有第二次消耗核心/材料。

首轮39项检查中30项通过、9项失败。9项是观察器将Dictionary中整数/浮点费用直接比较，以及以JSON字符串比较恢复前后数值类型的假设失败；实际核心扣款、等级、库存、词条、重复按钮检查均通过。首轮日志、39项原始审计与实际存档保留，未改生产逻辑或放宽实际扣款约束。

只复核失败观察项，使用首次原生支付已导出的真实档；没有重做支付。费用按数值语义核为1/0/1，三个恢复完整命名空间相等，三份已付款档及父输入SHA保持。复核17项中16项通过，剩余1项并非复扣：现代化同收据请求从QA审计JSON读取后，target_level整数20变成浮点20.0，原fingerprint含20，重放fingerprint含20.0，领域返回command_conflict。复核审计记录before==after，余额/材料未变。还原和再究极同收据重放均返回缓存结果且不扣款。

因此“重复点击/实际保存恢复不复扣”有直接证据；“未经整数schema复原的现代化请求跨JSON也返回缓存成功”没有通过。该事务请求类型边界保留给父评估，不称已修复，不把拒绝与成功缓存混为一谈，也不以此否定已实际完成的合法支付链。

复核脚本的原始输出audit路径与首次native目录重合，执行完成后已把复核审计与最终图归档到observer-retest，并用执行前留存的first-pass-observer-audit恢复首轮native/audit；两份原始结果均保留。脚本、文件与SHA清单可审阅。

## 剩余边界

本次补齐原先没有真实核心的合法生命周期缺口。普通零词条免费是否设计所需、停用究极附加词条是否计价、约1h目标是否包括究极/是否保留同批装备仍属用户决策边界，本次没有改变规则或验收口径。对父目前现役非究极60级的结论仍保留“一次真实付费现代化，部分天然换装”，不能改写为原全身逐架现代化。
