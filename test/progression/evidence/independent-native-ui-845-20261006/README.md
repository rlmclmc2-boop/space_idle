# 845独立原生UI证据（仅证据分支）

候选基准845d2ea206379ca186a6fe0d4a5bf876d7a8b5c5；自建887文件指纹4e07f51458d778fa152222ab0d39042cc07f4d7f83d2e1c563479de5e4123983。本分支只添加本目录，不改变生产、QA入口、配置或代码候选。原生1373×883 x11窗口；旧0a真实档正式载入845并重生成战点，不是父同版本数值CP，也不是新长跑。

优先读图：

- [光束首行与数值](native/05-beam-first-stats-hint-screen.png)
- [光束关闭重开](native/06-beam-reopened-hint-screen.png)
- [排队等待、未扣票、取消与退路](native/01-real-combat-queued-screen.png)
- [实际扣108000后](native/03-actual-paid-manual-entry-screen.png)
- [退出与单次退票](exit-retest/02-native-single-refund-repeat-stable-screen.png)
- [已付检查点重启恢复：退款正确，缺说明](paid-reload/01-paid-checkpoint-formal-recovery-screen.png)
- [再次载入同票据不叠加退款](paid-reload/02-same-paid-checkpoint-second-recovery-screen.png)
- [完整报告](845真实UI独立复验报告.md)

## 已付恢复缺说明：最小复现

输入为本轮**真实原生付票后**导出的[paid-candidate-checkpoint.json](exit-retest/paid-candidate-checkpoint.json)，不是手工构造票据。active.mode=manual、status=started、energy=61107.775193608、ticket=108000、return_journey.stage=5/groupIndex=0；对应库存和原真实源未赠送或刷seed。

1. 在845本机自建、导入的scene QA项目，新建正常窗口，正式load_progress_data(input.save)后resume_progress；避免离线收益的方法同报告：仅内存副本重基准chronoSavedAt/hightechSavedAt、保留原chrono余额。
2. 原生进入“异空间”。已自动取消中断探索，能量169107.775193608、active为空、主线第5关/战点0，库存与保存输入相同。
3. 画面只显示“自动探索已停止；可开始手动探索”，recent_result为空且不显示。再读同一票据金额不叠加，但仍没有中断退款说明。

仓库定位：hyperspace_system.gd load_state保存loaded_return并complete(false)；hyperspace_manual_session.gd reset_for_load清空last_result；hyperspace_panel.gd refresh_progress按session.last_result决定recent_result显示。此项是低优先级体验反馈，不是退款错误。

**应展示语义**：上次手动探索已中断；对应武器路线/等级；实际退回的门票金额；返回主线关卡/战点。例如本样本“上次脉冲5级探索已中断，门票108000已退回；已返回主线第5关、战点0”。沿用已有最近探索/恢复提示区域与实际恢复结果即可；不要新增奖励、重试任务、后台战斗、持久化账本或新的恢复机制，也不要硬编码票价。

## 消费端复现入口

在消费者自己目录，从指定候选commit执行`python test/progression/build_qa.py --scene --output <自己的QA目录>`，按本机Godot导入。将本目录independent_native_ui.gd复制到该QA项目qa；设置`QA_PAID_RELOAD=1`与`QA_RELOAD_FILE=<消费者自己的绝对paid-candidate-checkpoint.json路径>`，用正常图形Godot启动`--path <自己的QA目录> --script res://qa/independent_native_ui.gd`。观察器默认输出/tmp/qa845-evidence/paid-reload，可按消费者本机目录调整输出；父/本分支的绝对路径不能直接当作消费者路径。该入口只做实际付票检查点正式恢复、原生导航及重复载入，不重跑25个已过操作。

BUG修复后在原线程仅复验此项及直接影响：恢复说明读到实际路线/等级/金额/返回点；单次退款与再次加载不叠加；无中断的普通源不出现虚假退款说明。不得根据本分支旧845画面宣称修复候选通过。

## 首次失败与范围

first-pass-input-and-readiness保留初始观察器路线初始化顺序/菜单元数据错误和失败图日志。native正式轮的单项全等失败来自正常恢复在线能量增长，事件退款本身108000；exit-retest只补该边界，保留全部原件。详情见报告。

原始QA构建manifest和逐件SHA在本目录；Godot导入修改16个.import元数据，生产代码/数据无变化。凭据扫描无命中；不含.env、git配置、认证文件、Library签名传输对象或与此次测试无关的数据。用户已明确授权本次长测存档和动作日志公开同步。


后续真实存档退票提示补丁复验：[fb4392独立报告](refund-notice-independent-fb4392/README.md)。包含已付票、已结算、未付票、普通档和关闭重开实际页面证据。


父真实clear60来源的845独立界面复验：[星系与四路线现代化](parent-real-clear60-independent-ui/README.md)。来源含跨版本前缀与45恢复，报告保留该边界。


真实2核心究极生命周期补缺：[原生还原→现代化→再究极](ultimate-lifecycle-real-two-cores/README.md)。实际10→alpha20、核心2→0；保留观察器数值类型失败及跨JSON请求20/20.0拒绝边界。


计数展示修正候选44c4d0d4：[真实版本2/5及挂设管理像素验证](integer-counter-format-44c4d0d4/README.md)。仅格式转换，原28项与生命周期证据保留。


挂设来源策略缺口与一次实际补操作：[真实拆解解锁、0级挂设验证](dismantle-earned-module-actual845/README.md)。保留自然全锁来源，不把补操作混入原长跑。

追加：dismantle-feedback-f8744214（UI候选与26项真实奖励短测）；galaxy-complete-parent-119457（真实第一星系完成页，无下一星系配置）。

追加：modernization-base-cost-83af2544，正常窗口真实白机支付190、词条机不足与究极阻断，保留观察标签字段失败。

追加：readonly-restore-and-complete-ux，仅现有还原前材料风险/满级船员召回提示的只读评审和建议，未改生产规则。
